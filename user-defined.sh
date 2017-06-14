cat enwikivoyage-20141226-listings.osm |\
sed -e "s/tourism' v='information/user_defined' v='user_defined/g" |\
sed -e "s/tourism' v='attraction/user_defined' v='user_defined/g" |\
sed -e "s/tourism' v='museum/user_defined' v='user_defined/g" |\
sed -e "s/shop' v='supermarket/user_defined' v='user_defined/g" |\
sed -e "s/amenity' v='bar/user_defined' v='user_defined/g" |\
sed -e "s/amenity' v='restaurant/user_defined' v='user_defined/g" |\
sed -e "s/amenity' v='hotel/user_defined' v='user_defined/g" \
> enwikivoyage-20141226-listings-custom.osm
