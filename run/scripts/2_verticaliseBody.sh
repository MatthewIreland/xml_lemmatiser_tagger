inFile="$1"
[ -e "$inFile.body" ] && inFile="$inFile.body"
[ ! -e $inFile ] && echo "infile $inFile not found" && exit 1

outFile="$inFile.vertical"
echo "verticalising $inFile"

tempFile=$outFile.temp

# replace existing newlines with spaces
cat $inFile | tr '\n' ' ' > $tempFile

# add newline after every xml tag close > if not there already
sed -i "s/>\(.\)/>\n\1/g" $tempFile
# add newline before every xml tag open < if not there already
sed -i "s/\(.\)</\1\n</g" $tempFile

punctuations="[.,:;_#-]"

# make and clear tempFile2
tempFile2=$tempFile.2
>$tempFile2

# loop through line by line
while read -r line; do
  # check for xml tags
  if grep -q '[<>]' <<< "$line"; then
    # skip verticalisation
    echo "$line" >> $tempFile2
    continue
  fi

  # replace spaces with newlines
  line="`sed "s/ /\n/g" <<< "$line"`"

  # add to tempFile2
  echo "$line" >> $tempFile2

done < $tempFile

# splitting the loops like this speeds things up, as the lines are shorter and sed works on smaller strings
# clear outFile
>$outFile

while read -r line; do
  # check for xml tags
  if grep -q '[<>]' <<< "$line"; then
    # skip verticalisation
    echo "$line" >> $outFile
    continue
  fi
  # handle punctuation and gluing
  # loop in case of sequences of punctuation
  while grep -q "[^ ^]$punctuations" <<< "$line"; do
    # add glue and newline before any punctuation without a space before
    line="`sed "s/\([^ ]\)\($punctuations\)/\1\n<g>\n\2/g" <<< "$line"`"
  done

  # handle mid-word apostrophes: keep the apostrophe with the first word, followed by a glue tag
  line="`sed "s/\(\S\)'\(\S\)/\1'\n<g>\n\2/g" <<< "$line"`"

  echo "$line" >> $outFile

done < $tempFile2

rm $tempFile $tempFile2
