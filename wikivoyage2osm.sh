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
REGEX_TITLE="^<title>"
REGEX_URL='^((https?|ftp|file):)?//[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$' # http://stackoverflow.com/a/3184819/226958 plus no-protocol
REGEX_LAT='^[-+]?([1-8]?[0-9](\.[0-9]+)?|90(\.0+)?)$' # http://stackoverflow.com/a/18690202
REGEX_LONG='^[-+]?(180(\.0+)?|((1[0-7][0-9])|([1-9]?[0-9]))(\.[0-9]+)?)$' # http://stackoverflow.com/a/18690202

# Initialize output.
OSM=$DESTINATION.osm
echo "<?xml version='1.0' encoding='UTF-8'?>" > $OSM
echo "<osm version='0.5' generator='wikivoyage2osm'>" >> $OSM
CSV=$DESTINATION.csv
echo "ID;NAME;ALT;ADDRESS;DIRECTIONS;PHONE;TOLLFREE;EMAIL;FAX;URL;HOURS;CHECKIN;CHECKOUT;IMAGE;PRICE;LAT;LON" > $CSV
INVALID_URL=invalid-url.log
INVALID_LATLONG=invalid-latlong.log
> $INVALID_URL
> $INVALID_LATLONG
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
  #NAME=`echo $LINE | sed -e "s/.*name[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #ALT=`echo $LINE | sed -e "s/.*alt[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #ADDRESS=`echo $LINE | sed -e "s/.*address[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #DIRECIONS=`echo $LINE | sed -e "s/.*directions[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #PHONE=`echo $LINE | sed -e "s/.*phone[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #TOLLFREE=`echo $LINE | sed -e "s/.*tollfree[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #EMAIL=`echo $LINE | sed -e "s/.*email[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #FAX=`echo $LINE | sed -e "s/.*fax[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #URL=`echo $LINE | sed -e "s/.*url[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #HOURS=`echo $LINE | sed -e "s/.*hours[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #CHECKIN=`echo $LINE | sed -e "s/.*checkin[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #CHECKOUT=`echo $LINE | sed -e "s/.*checkout[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #IMAGE=`echo $LINE | sed -e "s/.*image[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #PRICE=`echo $LINE | sed -e "s/.*price[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  LAT=`echo $LINE | sed -e "s/.*lat[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  LONG=`echo $LINE | sed -e "s/.*long[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  
  #echo "$ID;$NAME;$ALT;$ADDRESS;$DIRECTIONS;$PHONE;$TOLLFREE;$EMAIL;$FAX;$URL;$HOURS;$CHECKIN;$CHECKOUT;$IMAGE;$PRICE;$LAT;$LONG;" >> $CSV

  # Check attributes validity
  #if ! [[ -z $URL ]] && ! [[ $URL =~ $REGEX_URL ]]
  #then 
  #  echo " $URL" >> $INVALID_URL
  #fi
  if ! [[ -z $LAT ]] && ! [[ $LAT =~ $REGEX_LAT ]]
  then 
    echo "* $EDIT_PREFIX$LINK_TITLE$EDIT_MIDDLE$TITLE$EDIT_SUFFIX (lat) $LAT" >> $INVALID_LATLONG
  fi
  if ! [[ -z $LONG ]] && ! [[ $LONG =~ $REGEX_LONG ]]
  then 
    echo "* $EDIT_PREFIX$LINK_TITLE$EDIT_MIDDLE$TITLE$EDIT_SUFFIX (long) $LONG" >> $INVALID_LATLONG
  fi

  # TODO output to OSM file

  fi
done < $TMPFILE

echo "</osm>" >> $OSM
