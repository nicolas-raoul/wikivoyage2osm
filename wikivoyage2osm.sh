DESTINATION=rattanakosin
OUT=$DESTINATION.osm
echo "<?xml version='1.0' encoding='UTF-8'?>" > $OUT
echo "<osm version='0.5' generator='wikivoyage2osm'>" >> $OUT

#while read p; do
#  echo $p
#done < peptides.txt

cat $DESTINATION.wikicode |\
  tr '\n' ' ' |\
  sed -e "s/{{/\n{{/g" | sed -e "s/}}/}}\n/g" |\
  grep "{{listing\|{{do\|{{see\|{{buy\|{{drink\|{{eat\|{{sleep" \
  > /tmp/tmp

ID=1
while read POI; do
  echo "$POI" |\
    sed -e "s/.*name=\([^|]*\).*lat=\([^|]*\).*long=\([^|]*\).*/<node id=\"$ID\" visible=\"true\" lat=\"\2REMOVESPACE\" lon=\"\3REMOVESPACE\"><tag k=\"name\" v=\"\1REMOVESPACE\"\/><tag k=\"note\" v=\"note\"\/><tag k=\"amenity\" v=\"restaurant\"\/><\/node>/g" |\
    sed -e "s/ REMOVESPACE//g" |\
    grep -v 'lat=""' \
    >> $OUT
  ID=`expr $ID + 1`
done < /tmp/tmp

echo "</osm>" >> $OUT
