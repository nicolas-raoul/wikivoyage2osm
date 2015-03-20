#!/bin/sh

# Usage:
# Open listings CSV in spreadsheet program
# Filter out listings with no lat/long
# Configure INPUT/OUTPUT variables below
# Run

INPUT=latlon-but-no-img-stripped.csv
OUTPUT=latlon-but-no-img-stripped.kml

echo '<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://earth.google.com/kml/2.0">
<Document>
<name>M58/1</name>
<LookAt>
<longitude>-18.7587</longitude><latitude>18.505</latitude>
<range>2500000</range><tilt>0</tilt><heading>0</heading>
</LookAt>' > $OUTPUT

while read POI; do
  NAME=`echo $POI | sed -e "s/,[^,]*,[^,]*$//" | sed -e "s/&amp;/-/" | sed -e "s/&quot;/-/" | sed -e "s/&gt;/-/" | sed -e "s/&lt;/-/" | sed -e "s/&/-/"`
  LAT=`echo $POI | sed -e "s/^[^,]*,//" | sed -e "s/,[^,]*$//"`
  LONG=`echo $POI | sed -e "s/^[^,]*,[^,]*,//"`

  # KML use longitude.latitude, unlike most other GIS
  # https://developers.google.com/kml/documentation/kml_tut#placemarks
  # http://gis.stackexchange.com/questions/6037/latlon-or-lonlat-whats-the-right-way-to-display-coordinates-and-inputs
  echo "<Placemark><name>$NAME</name><Point><coordinates>$LONG,$LAT</coordinates></Point></Placemark>" >> $OUTPUT
done < $INPUT

echo '</Document>
</kml>' >> $OUTPUT
