inFile="$1"
[ -e "$inFile.vertical" ] && inFile="$inFile.vertical"
[ -e "$inFile.body.vertical" ] && inFile="$inFile.body.vertical"
[ ! -e $inFile ] && echo "infile $inFile not found" && exit 1

outFile="$inFile.crunched"
echo "crunching $inFile"

punctuations="[.,:;_#-]"

# clear outFile
>$outFile
>crunchErrors

# handle english-language notes in greek text, with greek quotes
inNoteTag=
inForeignTag=

lengthTotal=`wc -l "$inFile"`

lengthDone=0

# loop through line by line
while read -r line; do
  (( lengthDone ++ ))
  (( lengthDone % 1000 == 0 )) && echo "crunching [$lengthDone of $lengthTotal] $inFile"
  # check for xml tags
  if grep -q '[<>]' <<< "$line"; then
    if [ -z $inNoteTag ]; then
      # not in note tag
      if grep -q '<note .*[^/]>' <<< "$line"; then
        inNoteTag=1
        inForeignTag=
      fi
    else
      # in note tag
      if grep -q '</note' <<< "$line"; then
        inNoteTag=
        inForeignTag=
      elif grep -q '<foreign .*[^/]>' <<< "$line"; then
        inForeignTag=1
      elif grep -q '</foreign' <<< "$line"; then
        inForeignTag=
      fi
    fi
    # skip crunching
    echo "$line" >> $outFile
    continue
  fi

  # check if line is punctuation
  if grep -q "$punctuations" <<< "$line"; then
    # skip crunching
    echo "$line" >> $outFile
    continue
  fi

  if [ ! -z $inNoteTag ] && [ -z $inForeignTag ]; then
    # if we are in a note tag and not in a foreign tag, it's an english word so skip crunching
    echo "$line" >> $outFile
    continue
  fi

  # if we've got here, it's an actual greek word
  word="$line"
  tags=""
  lemmas=""
  others=""
  # get the lemmas, separated by semicolons, removing numbers from the end
  lemmas="`echo "$word" | cruncher -l 2>/dev/null| tail -n +2 | sed 's/[0-9]$//' | sort -u | head -c -1 | tr '\n' ';'`"
  # get the cruncher results into an array
  readarray -ts 1 crunchedA <<< `cruncher <<< $word 2>>crunchErrors | sed "s/<NL>//g" | sed "s#</NL>#\n#g"`
  # loop through crunched lines
  for crunched in "${crunchedA[@]}"; do
    # character before first space is the tag, support multi-character tags as well
    tag=`grep -o "^[^ ]*" <<< $crunched`
    # if tags doesn't have the tag in it already
    if ! grep -q "$tag" <<< "$tags"; then
      # set tags to tag if empty, otherwise append
      [ -z $tags ] && tags="$tag" || tags="$tags;$tag"
    fi
    # find the right pattern of text and whitespace
    other="`sed 's/^\S\s\s*\S\S*\s\s*//g' <<< "$crunched" | sed 's/\s\s*/./g'`"
    # same as with tags
    if ! grep -q "$other" <<< "$others"; then
      [ -z $others ] && others="$other" || others="$others;$other"
    fi
  done
  # always treat an apostrophe ' as ʼ, not as a breve diacritic (so a' becomes αʼ not ᾰ )
  word="`sed "s/'/ʼ/g" <<< "$word"`"
  lemmas="`sed "s/'/ʼ/g" <<< "$lemmas"`"
  # format: word<tab>Tag<tab>lemma<tab>other
  echo "`beta2uni <<< "$word"`"$'\t'"$tags"$'\t'"`beta2uni <<< "$lemmas"`"$'\t'"$others" >> $outFile
  # one line is faster as it doesn't have to repeatedly open the file
  # echo -n "`beta2uni <<< "$word"`" >> $outFile
  # echo -ne "\t" >> $outFile
  # echo -n "$tags" >> $outFile
  # echo -ne "\t" >> $outFile
  # echo -n "`beta2uni <<< "$lemmas"`" >> $outFile
  # echo -ne "\t" >> $outFile
  # echo "$others" >> $outFile

done < $inFile
