#!/bin/sh
A=$1
mkdir -p www
cat head.html > www/"$A".html
pandoc --highlight-style=zenburn < src/"$A".md >> www/"$A".html || exit 1
cat tail.html >> www/"$A".html
