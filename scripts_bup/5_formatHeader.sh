inFileH="$1"
inFileB="$2"
[ -z "$inFileB" ] && inFileB="$inFileH"

[ -e "$inFileH.header" ] && inFileH="$inFileH.header"

[ -e "$inFileB.body" ] && inFileB="$inFileB.body"
[ -e "$inFileB.vertical" ] && inFileB="$inFileB.vertical"
[ -e "$inFileB.crunched" ] && inFileB="$inFileB.crunched"
[ -e "$inFileB.metad"    ] && inFileB="$inFileB.metad"

[ ! -e "$inFileH" ] && echo "infile header $inFileH not found" && exit 1
[ ! -e "$inFileB" ] && echo "infile body $inFileB not found" && exit 1

outFile="`sed 's/\.header$//' <<< $inFileH`".vert

[ -e "$outFile" ] && echo "$outFile already exists, skipping assembly" && exit 0

# make and clear tempFile
tempFile="$outFile.temp"
>"$tempFile"

echo -n "<doc" >"$tempFile"
author="`grep -o "<author[^>]*>.*</author>" "$inFileH" | cut -d ">" -f2 | cut -d "<" -f1 | sort -u | head -c -1 | tr '\n' ';'`"
[ -z "$author" ] || echo -n ' author="'$author'"' >>"$tempFile"
title="`grep -o "<title[^>]*>.*</title>" "$inFileH" | cut -d ">" -f2 | cut -d "<" -f1 | sort -u | head -c -1 | tr '\n' ';'`"
[ -z "$title" ] || echo -n ' title="'$title'"' >>"$tempFile"
echo -n ' filename="'"`sed "s/\.xml.*$//" <<< "$inFileB" | sed "s;^.*/;;"`"'"' >>"$tempFile"
echo ">" >>"$tempFile"
cat "$inFileB" >>"$tempFile"
echo "</doc>" >>"$tempFile"

# doing processing to temporary files, then renaming to outFile, means that outFile only exists in a finished state for interrupting/restarting processing
mv "$tempFile" "$outFile"
echo "added header to $outFile"
