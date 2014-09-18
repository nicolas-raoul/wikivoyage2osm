#!/bin/bash
#
# Wikivoyage2OSM
#
# Extract Wikivoyage Points Of Interest (POI), validate them, and generate OpenStreetMap (OSM) and CSV files.
# Reference: https://en.wikivoyage.org/wiki/Wikivoyage:Listings
# To make URLs clickable in CSV files, search for 'http.*' and replace with '=HYPERLINK("&")' as per https://forum.openoffice.org/en/forum/viewtopic.php?f=9&t=18313#p83972
#
# Usage ./wikivoyage.sh enwikivoyage-20131130-pages-articles.xml
#
# License: GNU-GPLv3
# Website: https://github.com/nicolas-raoul/wikivoyage2osm
# Tracker: https://github.com/nicolas-raoul/wikivoyage2osm/issues
# Results: https://sourceforge.net/p/wikivoyage
set -x
####################################################
# Settings begin
####################################################

# Target file (unit test if none given).
DESTINATION=${1:-rattanakosin.xml}

# Whether to validate the Wikivoyage content
# Invalid items are logged in invalid-* files in the same directory.
VALIDATE=YES # YES or NO

# Whether to generate CSV and OSM files
GENERATE_CSV=YES # YES or NO
GENERATE_OSM=YES # YES or NO

####################################################
# Settings end
####################################################

# Constants
EDIT_PREFIX="[https://en.wikivoyage.org/w/index.php?title="
EDIT_MIDDLE="&action=edit "
EDIT_SUFFIX="]"

# Regular expressions
REGEX_TITLE='^<title>'
REGEX_TYPE='^(listing|do|see|buy|drink|eat|sleep)$'
REGEX_PHONE='^\+[-0-9 ]+$' # https://en.wikivoyage.org/wiki/Wikivoyage:Phone_numbers
REGEX_PHONE_STRICT='^\+[0-9 ]+ [-0-9]+$' # https://en.wikivoyage.org/wiki/Wikivoyage:Phone_numbers https://en.wikipedia.org/wiki/List_of_country_calling_codes
REGEX_TOLLFREE='^\+?[-0-9 ]+$' # Same as above but + is not required as toll free is incompatible with country code in some countries
REGEX_TOLLFREE_STRICT='^(\+[0-9 ]+ )?[-0-9]+$'
REGEX_EMAIL_CHAR='[[:alnum:]!#\$%&'\''\*\+/=?^_\`{|}~-]' # http://stackoverflow.com/a/14172402
REGEX_EMAIL="^${REGEX_EMAIL_CHAR}+(\.${REGEX_EMAIL_CHAR}+)*@([[:alnum:]]([[:alnum:]-]*[[:alnum:]])?\.)+[[:alnum:]]([[:alnum:]-]*[[:alnum:]])?$"
REGEX_URL='^((https?|ftp|file):)?//[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$' # http://stackoverflow.com/a/3184819 plus no-protocol
REGEX_LAT='^[-+]?([1-8]?[0-9](\.[0-9]+)?|90(\.0+)?)$' # http://stackoverflow.com/a/18690202
REGEX_LONG='^[-+]?(180(\.0+)?|((1[0-7][0-9])|([1-9]?[0-9]))(\.[0-9]+)?)$' # http://stackoverflow.com/a/18690202
REGEX_TIME='(1?[0-9](:[0-9]{2})?[A|P]M|[012][0-9]:[0-9]{2}|noon|midnight)'
REGEX_TIMESPAN="([MTWTFSau-]+ )?${TIME}[-–]${TIME}"
REGEX_HOURS="^(${REGEX_TIMESPAN}(, ${REGEX_TIMESPAN})*|24 hours daily)$" # https://en.wikivoyage.org/wiki/Wikivoyage:Time_and_date_formats
REGEX_CHECKIN="^${TIME}$"

# Initialize output.
if [[ $GENERATE_OSM == "YES" ]]
then
  OSM=$DESTINATION.osm
  echo "<?xml version='1.0' encoding='UTF-8'?>" > $OSM
  echo "<osm version='0.5' generator='wikivoyage2osm'>" >> $OSM
fi
if [[ $GENERATE_CSV == "YES" ]]
then
  CSV=$DESTINATION.csv
  echo "TITLE;TYPE;NAME;ALT;ADDRESS;DIRECTIONS;PHONE;TOLLFREE;EMAIL;FAX;URL;HOURS;CHECKIN;CHECKOUT;IMAGE;PRICE;LAT;LON;CONTENT" > $CSV
fi

if [[ $VALIDATE == "YES" ]]
then
  INVALID_TYPE=invalid-type.log
  INVALID_PHONE=invalid-phone.log
  INVALID_PHONE_STRICT=invalid-phone-strict.log
  INVALID_TOLLFREE=invalid-tollfree.log
  INVALID_TOLLFREE_STRICT=invalid-tollfree-strict.log
  INVALID_EMAIL=invalid-email.log
  INVALID_FAX=invalid-fax.log
  INVALID_FAX_STRICT=invalid-fax-strict.log
  INVALID_URL=invalid-url.log
  INVALID_LATLONG=invalid-latlong.log
  INVALID_HOURS=invalid-hours.log
  INVALID_CHECKINOUT=invalid-checkinout.log
  > $INVALID_TYPE
  > $INVALID_PHONE
  > $INVALID_PHONE_STRICT
  > $INVALID_TOLLFREE
  > $INVALID_TOLLFREE_STRICT
  > $INVALID_EMAIL
  > $INVALID_FAX
  > $INVALID_FAX_STRICT
  > $INVALID_URL
  > $INVALID_LATLONG
  > $INVALID_HOURS
  > $INVALID_CHECKINOUT
fi

# Transform the data into one POI or title per line.
POIS=`mktemp`
#DESTINATION_FILE=`readlink -f $DESTINATION.xml`
DESTINATION_FILE=`realpath $DESTINATION` # TODO Use "readlink -f" instead (installed by default on Ubuntu). Or automatically do: apt-get install realpath
cat $DESTINATION_FILE |\
  tr '\n' ' ' |\
  awk -vRS='{{' -vORS='\n{{' 1 |\
  awk -vRS='}}' -vORS='\n}}' 1 |\
  awk -vRS='<title>' -vORS='\n<title>' 1 |\
  awk -vRS='</title>' -vORS='\n</title>' 1 |\
  grep "{{listing|\|{{listing |{{do|\|{{do \|{{see|\|{{see \|{{buy|\|{{buy \|{{drink|\|{{drink \|{{eat|\|{{eat \|{{sleep|\|{{sleep \|<title>" \
  > $POIS
  # TODO filter out "{{see also" which is an unrelated template.
  echo "POIs written to $POIS"

# Process each line (POI or title).
ID=0
while read LINE; do
  if [[ "$LINE" =~ $REGEX_TITLE ]]
  then
    TITLE=`echo "$LINE" | sed -e "s/<title>//g" -e "s/<\/title>//g"`
    echo "$TITLE"
    LINK_TITLE=`echo "$TITLE" | tr " " "_"`
  else

    # Extract all data from the Wikivoyage POI listing
    # Explanation:
    # Get the value of the attribute we want: sed -e "s/.*name[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/"
    # Skip if information is not present: grep -v "{{"
    # Remove leading/trailing whitespace: sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'
    # Remove Left-to-Right mark character as it is implicit: sed -e 's/\xe2\x80\x8e//'
    TYPE=`echo "$LINE" | sed -e "s/.*{{[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
    NAME=`echo "$LINE" | sed -e "s/.*name[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
    ALT=`echo "$LINE" | sed -e "s/.*alt[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
    ADDRESS=`echo "$LINE" | sed -e "s/.*address[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
    DIRECTIONS=`echo "$LINE" | sed -e "s/.*directions[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
    PHONE=`echo "$LINE" | sed -e "s/.*phone[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g' | sed -e 's/\xe2\x80\x8e//'`
    TOLLFREE=`echo "$LINE" | sed -e "s/.*tollfree[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g' | sed -e 's/\xe2\x80\x8e//'`
    EMAIL=`echo "$LINE" | sed -e "s/.*email[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
    FAX=`echo "$LINE" | sed -e "s/.*fax[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
    URL=`echo "$LINE" | sed -e "s/.*url[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
    HOURS=`echo "$LINE" | sed -e "s/.*hours[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
    CHECKIN=`echo "$LINE" | sed -e "s/.*checkin[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
    CHECKOUT=`echo "$LINE" | sed -e "s/.*checkout[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
    IMAGE=`echo "$LINE" | sed -e "s/.*image[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
    PRICE=`echo "$LINE" | sed -e "s/.*price[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
    LAT=`echo "$LINE" | sed -e "s/.*lat[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
    LONG=`echo "$LINE" | sed -e "s/.*long[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
    CONTENT=`echo "$LINE" | sed -e "s/.*content[[:space:]]*=[[:space:]]*\([^}]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
    
    # Check attributes validity
    if [[ "$VALIDATE" == "YES" ]]
    then
      if ! [[ $TYPE =~ $REGEX_TYPE ]]
      then 
        echo "# $EDIT_PREFIX$LINK_TITLE$EDIT_MIDDLE$TITLE$EDIT_SUFFIX $TYPE" >> $INVALID_TYPE
      fi
      if ! [[ -z $PHONE ]] && ! [[ $PHONE =~ $REGEX_PHONE ]]
      then 
        echo "# $EDIT_PREFIX$LINK_TITLE$EDIT_MIDDLE$TITLE$EDIT_SUFFIX $PHONE" >> $INVALID_PHONE
      else
        if ! [[ -z $PHONE ]] && ! [[ $PHONE =~ $REGEX_PHONE_STRICT ]]
        then 
          echo "# $EDIT_PREFIX$LINK_TITLE$EDIT_MIDDLE$TITLE$EDIT_SUFFIX $PHONE" >> $INVALID_PHONE_STRICT
        fi
      fi
      if ! [[ -z $TOLLFREE ]] && ! [[ $TOLLFREE =~ $REGEX_TOLLFREE ]]
      then 
        echo "# $EDIT_PREFIX$LINK_TITLE$EDIT_MIDDLE$TITLE$EDIT_SUFFIX $TOLLFREE" >> $INVALID_TOLLFREE
      else
        if ! [[ -z $TOLLFREE ]] && ! [[ $TOLLFREE =~ $REGEX_TOLLFREE_STRICT ]]
        then 
          echo "# $EDIT_PREFIX$LINK_TITLE$EDIT_MIDDLE$TITLE$EDIT_SUFFIX $TOLLFREE" >> $INVALID_TOLLFREE_STRICT
        fi
      fi
      if ! [[ -z $EMAIL ]] && ! [[ $EMAIL =~ $REGEX_EMAIL ]]
      then 
        echo "# $EDIT_PREFIX$LINK_TITLE$EDIT_MIDDLE$TITLE$EDIT_SUFFIX $EMAIL" >> $INVALID_EMAIL
      fi
      if ! [[ -z $FAX ]] && ! [[ $FAX =~ $REGEX_PHONE ]] # Same regex as phone
      then 
        echo "# $EDIT_PREFIX$LINK_TITLE$EDIT_MIDDLE$TITLE$EDIT_SUFFIX $FAX" >> $INVALID_FAX
      else
        if ! [[ -z $FAX ]] && ! [[ $FAX =~ $REGEX_PHONE_STRICT ]]
        then 
          echo "# $EDIT_PREFIX$LINK_TITLE$EDIT_MIDDLE$TITLE$EDIT_SUFFIX $FAX" >> $INVALID_FAX_STRICT
        fi
      fi
      if ! [[ -z $URL ]] && ! [[ $URL =~ $REGEX_URL ]]
      then 
        echo "# $EDIT_PREFIX$LINK_TITLE$EDIT_MIDDLE$TITLE$EDIT_SUFFIX $URL" >> $INVALID_URL
      fi
      if ! [[ -z $LAT ]] && ! [[ $LAT =~ $REGEX_LAT ]]
      then 
        echo "# $EDIT_PREFIX$LINK_TITLE$EDIT_MIDDLE$TITLE$EDIT_SUFFIX (lat) $LAT" >> $INVALID_LATLONG
      fi
      if ! [[ -z $LONG ]] && ! [[ $LONG =~ $REGEX_LONG ]]
      then 
        echo "# $EDIT_PREFIX$LINK_TITLE$EDIT_MIDDLE$TITLE$EDIT_SUFFIX (long) $LONG" >> $INVALID_LATLONG
      fi
      if ! [[ -z $HOURS ]] && ! [[ $HOURS =~ $REGEX_HOURS ]]
      then 
        echo "# $EDIT_PREFIX$LINK_TITLE$EDIT_MIDDLE$TITLE$EDIT_SUFFIX $HOURS" >> $INVALID_HOURS
      fi
      if ! [[ -z $CHECKIN ]] && ! [[ $CHECKIN =~ $REGEX_CHECKIN ]]
      then 
        echo "# $EDIT_PREFIX$LINK_TITLE$EDIT_MIDDLE$TITLE$EDIT_SUFFIX (checkin) $CHECKIN" >> $INVALID_CHECKINOUT
      fi
      if ! [[ -z $CHECKOUT ]] && ! [[ $CHECKOUT =~ $REGEX_CHECKIN ]]
      then 
        echo "# $EDIT_PREFIX$LINK_TITLE$EDIT_MIDDLE$TITLE$EDIT_SUFFIX (checkout) $CHECKOUT" >> $INVALID_CHECKINOUT
      fi
      # It seems that $IMAGE does not need checking as anything is allowed: https://commons.wikimedia.org/wiki/Commons:Village_pump#Characters_allowed_in_Commons_filenames.3F https://commons.wikimedia.org/wiki/Commons:File_naming
    fi
  
    if [[ "$GENERATE_CSV" == "YES" ]]
    then
      CSVLINE="\"$TITLE\";\"$TYPE\";\"$NAME\";\"$ALT\";\"$ADDRESS\";\"$DIRECTIONS\";\"$PHONE\";\"$TOLLFREE\";\"$EMAIL\";\"$FAX\";\"$URL\";\"$HOURS\";\"$CHECKIN\";\"$CHECKOUT\";\"$IMAGE\";\"$PRICE\";\"$LAT\";\"$LONG\";\"$CONTENT\""
      # Unescape &amp; back to & because no need to escape ampersands in CSV.
      echo "$CSVLINE" | sed -e "s/&amp;/\&/g" >> $CSV
    fi

    if [[ "$GENERATE_OSM" == "YES" ]]
    then
      # Escape single quotes in values so that they can be used as XML attribute values.
      LAT=`echo "$LAT" | sed -e "s/'/\&quot;/g"`
      LONG=`echo "$LONG" | sed -e "s/'/\&quot;/g"`
      NAME=`echo "$NAME" | sed -e "s/'/\&quot;/g"`
      ALT=`echo "$ALT" | sed -e "s/'/\&quot;/g"`
      ADDRESS=`echo "$ADDRESS" | sed -e "s/'/\&quot;/g"`
      PHONE=`echo "$PHONE" | sed -e "s/'/\&quot;/g"`
      TOLLFREE=`echo "$TOLLFREE" | sed -e "s/'/\&quot;/g"`
      EMAIL=`echo "$EMAIL" | sed -e "s/'/\&quot;/g"`
      FAX=`echo "$FAX" | sed -e "s/'/\&quot;/g"`
      URL=`echo "$URL" | sed -e "s/'/\&quot;/g"`
      HOURS=`echo "$HOURS" | sed -e "s/'/\&quot;/g"`
      CHECKIN=`echo "$CHECKIN" | sed -e "s/'/\&quot;/g"`
      CHECKOUT=`echo "$CHECKOUT" | sed -e "s/'/\&quot;/g"`
      IMAGE=`echo "$IMAGE" | sed -e "s/'/\&quot;/g"`
      PRICE=`echo "$PRICE" | sed -e "s/'/\&quot;/g"`
      CONTENT=`echo "$CONTENT" | sed -e "s/'/\&quot;/g"`
    
      # Output to OSM file if latitude/longitude present.
      if ! [[ -z $LAT ]] && ! [[ -z $LONG ]]
      then
        ID=`expr $ID + 1`
        echo "<node id='$ID' visible='true' lat='$LAT' lon='$LONG'>" >> $OSM
        case "$TYPE" in
          "listing")
            echo "<tag k='tourism' v='information'/>" >> $OSM # http://wiki.openstreetmap.org/wiki/Key:tourism Unspecified listings are often tourism information, even though not always.
          ;;
          "do")
            echo "<tag k='tourism' v='attraction'/>" >> $OSM # http://wiki.openstreetmap.org/wiki/Key:tourism Must emcompass sport activities, cinema, theme parks.
          ;;
          "see")
            echo "<tag k='tourism' v='museum'/>" >> $OSM # http://wiki.openstreetmap.org/wiki/Key:tourism Often museums, the icon also kind of apply for outdoor sights.
          ;;
          "buy")
            echo "<tag k='shop' v='supermarket'/>" >> $OSM # http://wiki.openstreetmap.org/wiki/Key:shop amenity:marketplace could apply too, but the icon for supermarket is much more recognizable.
          ;;
          "drink")
            echo "<tag k='amenity' v='bar'/>" >> $OSM # http://wiki.openstreetmap.org/wiki/Key:amenity
          ;;
          "eat")
            echo "<tag k='amenity' v='restaurant'/>" >> $OSM # http://wiki.openstreetmap.org/wiki/Key:amenity This is OSM's most general type of restaurants.
          ;;
          "sleep")
            echo "<tag k='amenity' v='hotel'/>" >> $OSM # http://wiki.openstreetmap.org/wiki/Key:tourism
          ;;
        esac
        if ! [[ -z $NAME ]]
        then 
          echo "<tag k='name' v='$NAME'/>" >> $OSM
        fi
        if ! [[ -z $ALT ]]
        then 
          echo "<tag k='alt_name' v='$ALT'/>" >> $OSM
        fi
        if ! [[ -z $ADDRESS ]]
        then 
          echo "<tag k='addr:full' v='$ADDRESS'/>" >> $OSM
        fi
        if ! [[ -z $PHONE ]]
        then 
          echo "<tag k='phone' v='$PHONE'/>" >> $OSM
        fi
        if ! [[ -z $TOLLFREE ]]
        then 
          echo "<tag k='phone' v='$TOLLFREE'/>" >> $OSM
        fi
        if ! [[ -z $EMAIL ]]
        then 
          echo "<tag k='email' v='$EMAIL'/>" >> $OSM
        fi
        if ! [[ -z $FAX ]]
        then 
          echo "<tag k='fax' v='$FAX'/>" >> $OSM
        fi
        if ! [[ -z $URL ]]
        then 
          echo "<tag k='website' v='$URL'/>" >> $OSM
        fi
        if ! [[ -z $HOURS ]]
        then 
          echo "<tag k='opening_hours' v='$HOURS'/>" >> $OSM
        fi
        if ! [[ -z $CHECKIN ]]
        then 
          echo "<tag k='opening_hours:checkin' v='$CHECKIN'/>" >> $OSM
        fi
        if ! [[ -z $CHECKOUT ]]
        then 
          echo "<tag k='opening_hours:checkout' v='$CHECKOUT'/>" >> $OSM
        fi
        if ! [[ -z $IMAGE ]]
        then 
          echo "<tag k='image' v='https://commons.wikimedia.org/wiki/File:$IMAGE'/>" >> $OSM
        fi
        if ! [[ -z $PRICE ]]
        then 
          echo "<tag k='price' v='$PRICE'/>" >> $OSM
        fi
        if ! [[ -z $CONTENT ]]
        then 
          echo "<tag k='note' v='$CONTENT'/>" >> $OSM
        fi
        echo "</node>" >> $OSM
      fi
    fi
  fi
done < $POIS

if [[ $GENERATE_OSM == "YES" ]]
then
  echo "</osm>" >> $OSM
fi
