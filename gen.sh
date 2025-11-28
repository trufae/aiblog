#!/bin/sh
A=$1
mkdir -p www
TITLE=`grep '^#' src/${A}.md | head -n1|cut -d ' ' -f 2-`
echo "$A ($TITLE)"
sed -e "s,TITLE,${TITLE}," < head.html > www/"$A".html
# debian
pandoc --highlight-style=zenburn < src/"$A".md >> www/"$A".html || exit 1
# macos
# pandoc --syntax-highlighting=zenburn < src/"$A".md >> www/"$A".html || exit 1
cat tail.html >> www/"$A".html
