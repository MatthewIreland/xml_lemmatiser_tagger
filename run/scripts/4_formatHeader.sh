inFileH="$1"
inFileB="$2"
[ -z $inFileB ] && inFileB="$inFileH"

[ -e "$inFileH.header" ] && inFileH="$inFileH.header"
outFile="`sed 's/\.header$//' <<< $inFileH`".vert

[ -e "$inFileB.crunched" ] && inFileB="$inFileB.crunched"
[ -e "$inFileB.vertical.crunched" ] && inFileB="$inFileB.vertical.crunched"
[ -e "$inFileB.body.vertical.crunched" ] && inFileB="$inFileB.body.vertical.crunched"

[ ! -e "$inFileH" ] && echo "infile header $inFileH not found" && exit 1
[ ! -e "$inFileB" ] && echo "infile body $inFileB not found" && exit 1

echo -n "<doc" >$outFile
author="`grep -o "<author[^>]*>.*</author>" $inFileH | cut -d ">" -f2 | cut -d "<" -f1 | sort -u | head -c -1 | tr '\n' ';'`"
[ -z "$author" ] || echo -n ' author="'$author'"' >>$outFile
title="`grep -o "<title[^>]*>.*</title>" $inFileH | cut -d ">" -f2 | cut -d "<" -f1 | sort -u | head -c -1 | tr '\n' ';'`"
[ -z "$title" ] || echo -n ' title="'$title'"' >>$outFile
echo -n ' filename="'"`sed "s/\.xml.*$//" <<< "$inFileB" | sed "s;^.*/;;"`"'"' >>$outFile
echo ">" >>$outFile
cat "$inFileB" >>$outFile
echo "</doc>" >>$outFile
echo "done $outFile"
