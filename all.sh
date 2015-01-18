#!/bin/bash

# Download the latest dump from the Wikivoyage server and transform it to an HTML guide.

wget http://dumps.wikimedia.org/enwikivoyage/ -O /tmp/dump-dates.txt
LAST_DUMP_LINE=`grep Directory /tmp/dump-dates.txt | grep -v latest | tail -n 1`
LAST_DUMP_DATE=`echo $LAST_DUMP_LINE | sed -e "s/<\/a>.*//g" -e "s/.*>//g"`
echo "Last dump date: $LAST_DUMP_DATE"

# Check if already downloaded
if [ -f enwikivoyage-$LAST_DUMP_DATE-pages-articles.xml ];
then
   echo "Already present. Exiting."
   exit
else
   echo "Not present yet. Generating."
fi

wget http://dumps.wikimedia.org/enwikivoyage/$LAST_DUMP_DATE/enwikivoyage-$LAST_DUMP_DATE-pages-articles.xml.bz2

bunzip2 enwikivoyage-$LAST_DUMP_DATE-pages-articles.xml.bz2

./wikivoyage2osm.sh enwikivoyage-$LAST_DUMP_DATE-pages-articles.xml

mv enwikivoyage-$LAST_DUMP_DATE-pages-articles.xml.csv enwikivoyage-$LAST_DUMP_DATE-listings.csv
mv enwikivoyage-$LAST_DUMP_DATE-pages-articles.xml.osm enwikivoyage-$LAST_DUMP_DATE-listings.osm
