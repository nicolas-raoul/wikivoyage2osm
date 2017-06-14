#!/bin/sh
#
# Create a subset of a listings CSV file, containing only destination, name, lat, long
#
# Requires csvkit. Ubuntu: sudo pip install csvkit

csvcut -d ";" -c 1,3,17,18 enwikivoyage-20150409-listings.csv | grep -v ",,$" >/tmp/out.csv


