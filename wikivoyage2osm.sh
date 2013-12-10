#!/bin/bash
# Wikivoyage2OSM
# Extract Wikivoyage Points Of Interest (POI), check them, and generate an OpenStreetMap (OSM) file.
# Reference: https://en.wikivoyage.org/wiki/Wikivoyage:Listings
# To make URLs clickable in CSV files, search for 'http.*' and replace with '=HYPERLINK("&")' as per https://forum.openoffice.org/en/forum/viewtopic.php?f=9&t=18313#p83972

# Target file (unit test, or whole Wikivoyage).
#DESTINATION=rattanakosin
DESTINATION=enwikivoyage-20131130-pages-articles

# Constants
EDIT_PREFIX="[https://en.wikivoyage.org/w/index.php?title="
EDIT_MIDDLE="&action=edit "
EDIT_SUFFIX="]"

# Regular expressions
REGEX_TITLE='^<title>'
REGEX_PHONE='^\+[-0-9 ]+$' # https://en.wikivoyage.org/wiki/Wikivoyage:Phone_numbers
REGEX_PHONE_STRICT='^\+[0-9 ]+ [-0-9]+$' # https://en.wikivoyage.org/wiki/Wikivoyage:Phone_numbers https://en.wikipedia.org/wiki/List_of_country_calling_codes
REGEX_TOLLFREE='^\+?[-0-9 ]+$' # Same as above but + is not required as toll free is incompatible with country code in some countries
REGEX_TOLLFREE_STRICT='^(\+[0-9 ]+ )?[-0-9]+$'
REGEX_EMAIL_CHAR='[[:alnum:]!#\$%&'\''\*\+/=?^_\`{|}~-]' # http://stackoverflow.com/a/14172402
REGEX_EMAIL="^${REGEX_EMAIL_CHAR}+(\.${REGEX_EMAIL_CHAR}+)*@([[:alnum:]]([[:alnum:]-]*[[:alnum:]])?\.)+[[:alnum:]]([[:alnum:]-]*[[:alnum:]])?$"
REGEX_URL='^((https?|ftp|file):)?//[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$' # http://stackoverflow.com/a/3184819 plus no-protocol
REGEX_LAT='^[-+]?([1-8]?[0-9](\.[0-9]+)?|90(\.0+)?)$' # http://stackoverflow.com/a/18690202
REGEX_LONG='^[-+]?(180(\.0+)?|((1[0-7][0-9])|([1-9]?[0-9]))(\.[0-9]+)?)$' # http://stackoverflow.com/a/18690202
REGEX_TIME='(1?[0-9](:[0-9]{2}?)[A|P]M|[012][0-9]:[0-9]{2}|noon|midnight)'
REGEX_TIMESPAN="([MTWTFSau-]+ )?${TIME}[-–]${TIME}"
REGEX_HOURS="^(${REGEX_TIMESPAN}(, ${REGEX_TIMESPAN})*|24 hours daily)$"
REGEX_CHECKIN="^${TIME}$"

# Initialize output.
OSM=$DESTINATION.osm
echo "<?xml version='1.0' encoding='UTF-8'?>" > $OSM
echo "<osm version='0.5' generator='wikivoyage2osm'>" >> $OSM
CSV=$DESTINATION.csv
echo "ID;NAME;ALT;ADDRESS;DIRECTIONS;PHONE;TOLLFREE;EMAIL;FAX;URL;HOURS;CHECKIN;CHECKOUT;IMAGE;PRICE;LAT;LON" > $CSV
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
TMPFILE=`mktemp`

# Transform the data into one POI or title per line.
cat $DESTINATION.xml |\
  tr '\n' ' ' |\
  sed -e "s/{{/\n{{/g" | sed -e "s/}}/}}\n/g" |\
  sed -e "s/<title>/\n<title>/g" | sed -e "s/<\/title>/<\/title>\n/g" |\
  grep "{{listing|\|{{listing |{{do|\|{{do \|{{see|\|{{see \|{{buy|\|{{buy \|{{drink|\|{{drink \|{{eat|\|{{eat \|{{sleep|\|{{sleep \|<title>" \
  > $TMPFILE

# Process each line (POI or title).
ID=0
while read LINE; do
  if [[ $LINE =~ $REGEX_TITLE ]]
  then
    TITLE=`echo $LINE | sed -e "s/<title>//g" -e "s/<\/title>//g"`
    echo $TITLE
    LINK_TITLE=`echo $TITLE | tr " " "_"`
  else
  ID=`expr $ID + 1`

  # Explanation:
  # Extract the information: sed -e "s/.*name[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/"
  # Skip if information is not present: grep -v "{{"
  # Remove leading/trailing whitespace: sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'
  # Remove Left-to-Right mark character: sed -e 's/\xe2\x80\x8e//'
  NAME=`echo $LINE | sed -e "s/.*name[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  ALT=`echo $LINE | sed -e "s/.*alt[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  ADDRESS=`echo $LINE | sed -e "s/.*address[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  DIRECIONS=`echo $LINE | sed -e "s/.*directions[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  PHONE=`echo $LINE | sed -e "s/.*phone[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g' | sed -e 's/\xe2\x80\x8e//'`
  TOLLFREE=`echo $LINE | sed -e "s/.*tollfree[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g' | sed -e 's/\xe2\x80\x8e//'`
  EMAIL=`echo $LINE | sed -e "s/.*email[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  FAX=`echo $LINE | sed -e "s/.*fax[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  URL=`echo $LINE | sed -e "s/.*url[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  HOURS=`echo $LINE | sed -e "s/.*hours[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  CHECKIN=`echo $LINE | sed -e "s/.*checkin[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  CHECKOUT=`echo $LINE | sed -e "s/.*checkout[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  IMAGE=`echo $LINE | sed -e "s/.*image[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  PRICE=`echo $LINE | sed -e "s/.*price[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  LAT=`echo $LINE | sed -e "s/.*lat[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  LONG=`echo $LINE | sed -e "s/.*long[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  
  echo "$ID;$NAME;$ALT;$ADDRESS;$DIRECTIONS;$PHONE;$TOLLFREE;$EMAIL;$FAX;$URL;$HOURS;$CHECKIN;$CHECKOUT;$IMAGE;$PRICE;$LAT;$LONG;" >> $CSV

  # Check attributes validity
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

  # TODO output to OSM file

  fi
done < $TMPFILE

echo "</osm>" >> $OSM
