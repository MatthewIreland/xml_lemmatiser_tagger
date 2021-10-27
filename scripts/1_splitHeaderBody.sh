inFile="$1"
[ ! -e "$inFile" ] && echo "infile $inFile not found" && exit 1

echo "splitting header and body of $inFile"

if grep -q "</teiHeader>" "$inFile"; then
  lineNum=`sed -n '\#</teiHeader>#=' "$inFile"`
  sed -n "p;$lineNum""q" "$inFile" > "$inFile.header"
  sed -n "$(( lineNum + 1))"',$p' "$inFile" > "$inFile.body"
else
  echo "header not found, using default"
  cp files/defaultHeader.xml "$inFile.header"
  cp "$inFile" "$inFile.body"
fi

# remove closing tei2 tag
sed -i "s#</TEI.*>##g" "$inFile.body"
