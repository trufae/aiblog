#!/bin/sh
A=$1
cat head.html > "$A".html
pandoc --highlight-style=zenburn < "$A".md >> "$A".html
cat tail.html >> "$A".html
