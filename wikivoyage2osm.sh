#!/bin/bash
# Wikivoyage2OSM
# Extract Wikivoyage Points Of Interest (POI), check them, and generate an OpenStreetMap (OSM) file.
# Reference: https://en.wikivoyage.org/wiki/Wikivoyage:Listings

# Target file (unit test, or whole Wikivoyage).
#DESTINATION=rattanakosin
DESTINATION=enwikivoyage-20131130-pages-articles

# Initialize output.
OSM=$DESTINATION.osm
echo "<?xml version='1.0' encoding='UTF-8'?>" > $OSM
echo "<osm version='0.5' generator='wikivoyage2osm'>" >> $OSM
CSV=$DESTINATION.csv
echo "ID;NAME;ALT;ADDRESS;DIRECTIONS;PHONE;TOLLFREE;EMAIL;FAX;URL;HOURS;CHECKIN;CHECKOUT;IMAGE;PRICE;LAT;LON" > $CSV
INVALID_URL=invalid-url.log
>$INVALID_URL
INVALID_LAT=invalid-lat.log
>$INVALID_LAT
INVALID_LONG=invalid-long.log
>$INVALID_LONG

# Validation regex
REGEX_URL='^((https?|ftp|file):)?//[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]$' # http://stackoverflow.com/a/3184819/226958 plus no-protocol
REGEX_LAT='^[-+]?\d{1,2}([.]\d+)?$' # http://stackoverflow.com/a/14155725/226958
REGEX_LONG='^[-+]?\d{1,3}([.]\d+)?$' # http://stackoverflow.com/a/14155725/226958

# Transform the data into one POI per line.
cat $DESTINATION.xml |\
  tr '\n' ' ' |\
  sed -e "s/{{/\n{{/g" | sed -e "s/}}/}}\n/g" |\
  grep "{{listing|\|{{listing |{{do|\|{{do \|{{see|\|{{see \|{{buy|\|{{buy \|{{drink|\|{{drink \|{{eat|\|{{eat \|{{sleep|\|{{sleep " \
  > /tmp/tmp

# Process each POI.
ID=0
while read POI; do
  ID=`expr $ID + 1`

  # Explanation:
  # Extract the information: sed -e "s/.*name[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/"
  # Skip if information is not present: grep -v "{{"
  # Remove leading/trailing whitespace: sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'
  #NAME=`echo $POI | sed -e "s/.*name[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #ALT=`echo $POI | sed -e "s/.*alt[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #ADDRESS=`echo $POI | sed -e "s/.*address[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #DIRECIONS=`echo $POI | sed -e "s/.*directions[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #PHONE=`echo $POI | sed -e "s/.*phone[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #TOLLFREE=`echo $POI | sed -e "s/.*tollfree[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #EMAIL=`echo $POI | sed -e "s/.*email[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #FAX=`echo $POI | sed -e "s/.*fax[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #URL=`echo $POI | sed -e "s/.*url[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #HOURS=`echo $POI | sed -e "s/.*hours[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #CHECKIN=`echo $POI | sed -e "s/.*checkin[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #CHECKOUT=`echo $POI | sed -e "s/.*checkout[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #IMAGE=`echo $POI | sed -e "s/.*image[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  #PRICE=`echo $POI | sed -e "s/.*price[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  LAT=`echo $POI | sed -e "s/.*lat[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  LONG=`echo $POI | sed -e "s/.*long[[:space:]]*=[[:space:]]*\([^|]*\).*/\1/" | grep -v "{{" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'`
  
  #echo "$ID;$NAME;$ALT;$ADDRESS;$DIRECTIONS;$PHONE;$TOLLFREE;$EMAIL;$FAX;$URL;$HOURS;$CHECKIN;$CHECKOUT;$IMAGE;$PRICE;$LAT;$LONG;" >> $CSV

  # Check attributes validity
  #if ! [[ -z $URL ]] && ! [[ $URL =~ $REGEX_URL ]]
  #then 
  #  echo " $URL" >> $INVALID_URL
  #fi
  if ! [[ -z $LAT ]] && ! [[ $LAT =~ $REGEX_LAT ]]
  then 
    echo " $LAT" >> $INVALID_LAT
  fi
  if ! [[ -z $LONG ]] && ! [[ $LONG =~ $REGEX_LONG ]]
  then 
    echo " $LONG" >> $INVALID_LONG
  fi

  # TODO output to OSM file
done < /tmp/tmp

echo "</osm>" >> $OSM
