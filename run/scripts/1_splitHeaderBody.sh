inFile="$1"
[ ! -e $inFile ] && echo "infile $inFile not found" && exit 1
echo "splitting header and body of $inFile"
lineNum=`sed -n '\#</teiHeader>#=' "$inFile"`
sed -n "p;$lineNum""q" "$inFile" > "$inFile.header"
sed -n "$(( lineNum + 1))"',$p' "$inFile" > "$inFile.body"
# remove closing tei2 tag
sed -i "s#</TEI.2>##g" "$inFile.body"
