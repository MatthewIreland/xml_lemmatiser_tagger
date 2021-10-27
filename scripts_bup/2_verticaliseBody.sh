already_unicode=
while getopts ":u" arg
do	case "$arg" in
	u) already_unicode=1 ;;
	h | *)	echo "usage: ./scriptName.sh [-u if file is in unicode not betacode] fileName"; exit 1;;
	esac
done

shift $((OPTIND-1))

inFile="$1"
[ -e "$inFile.body" ] && inFile="$inFile.body"
[ ! -e "$inFile" ] && echo "infile $inFile not found" && exit 1

outFile="$inFile.vertical"

[ -e "$outFile" ] && echo "$outFile already exists, skipping verticalisation" && exit 0

[ ! -z $already_unicode ] && echo "verticalising $inFile as unicode" || echo "verticalising $inFile as beta-code"

tempFile="$outFile.temp"

# replace existing newlines with spaces
cat "$inFile" | tr '\n' ' ' > "$tempFile"

# add newline after every xml tag close > if not there already
sed -i "s/>\(.\)/>\n\1/g" "$tempFile"
# add newline before every xml tag open < if not there already
sed -i "s/\(.\)</\1\n</g" "$tempFile"

punctuations="[.,:;_#-]"
[ ! -z $already_unicode ] && punctuations="[][]()<>†“”‘’&·—ʹ.,:;_#-]"

# make and clear tempFile2
tempFile2="$tempFile.2"
>"$tempFile2"

# loop through line by line
while read -r line; do
  # check for xml tags
  if grep -q '[<>]' <<< "$line"; then
    # skip verticalisation
    echo "$line" >> "$tempFile2"
    continue
  fi

  # replace spaces with newlines
  line="`sed "s/ /\n/g" <<< "$line"`"

  # add to tempFile2
  echo "$line" >> "$tempFile2"

done < "$tempFile"

# remove empty lines
mv "$tempFile2" "$tempFile"
grep "." "$tempFile" > "$tempFile2"

# splitting the loops like this speeds things up, as the lines are shorter and sed works on smaller strings
# rename tempFile2 to tempFile, and clear tempFile2, so we can again use tempFile as an input and tempFile2 as an output
mv "$tempFile2" "$tempFile"
>"$tempFile2"

while read -r line; do
  # check for xml tags
  if grep -q '[<>]' <<< "$line"; then
    # skip verticalisation
    echo "$line" >> "$tempFile2"
    continue
  fi

  # handle &lpar; codes for literal parentheses
  # check for sequences like &lpar;ai( which should go to crunching as &lpar; \n <g> \n ai(
  # check for word&lpar;
  # add glue and a newline before any & without a newline before it already
  line="`sed "s/\([^^]\)&/\1\n<g>\n\&/g" <<< "$line"`"
  # check for &lpar;word
  # add a glue and newline after any &[^;]*; without a newline after it already
  line="`sed "s/\(&[^;]*;\)\([^$]\)/\1\n<g>\n\2/g" <<< "$line"`"

  # handle mid-word apostrophes: keep the apostrophe with the first word, followed by a glue tag
  line="`sed "s/\(\S\)'\(\S\)/\1'\n<g>\n\2/g" <<< "$line"`"

  echo "$line" >> "$tempFile2"
done < "$tempFile"

# rename tempFile2 to tempFile, and clear tempFile2, so we can again use tempFile as an input and tempFile2 as an output
mv "$tempFile2" "$tempFile"
>"$tempFile2"

while read -r line; do
  # check for xml tags
  if grep -q '[<>]' <<< "$line"; then
    # skip verticalisation
    echo "$line" >> "$tempFile2"
    continue
  fi
  # check for &...; sequences like &lpar; to not treat the ; as punctuation
  if grep -q "&[^;]*;" <<< "$line"; then
    # skip punctuation handling
    echo "$line" >> "$tempFile2"
    continue
  fi

  # handle punctuation and gluing
  # check for punctuation after a word
  # loop in case of sequences of punctuation
  while grep -q "[^^]$punctuations" <<< "$line"; do
    # add glue and newline before any punctuation without a newline before
    line="`sed "s/\([^^]\)\($punctuations\)/\1\n<g>\n\2/g" <<< "$line"`"
  done
  # check for punctuation after a word
  # loop in case of sequences of punctuation
  while grep -q "$punctuations[^$]" <<< "$line"; do
    # add glue and newline before any punctuation without a newline before
    line="`sed "s/\($punctuations\)\([^$]\)/\1\n<g>\n\2/g" <<< "$line"`"
  done

  echo "$line" >> "$tempFile2"
done < "$tempFile"

# doing processing to temporary files, then renaming to outFile, means that outFile only exists in a finished state for interrupting/restarting processing
mv "$tempFile2" "$outFile"
rm "$tempFile"
echo "done verticalising $outFile"
