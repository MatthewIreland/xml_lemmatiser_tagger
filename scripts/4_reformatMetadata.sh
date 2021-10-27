DEBUG_VERBOSE=

inFile="$1"
[ -e "$inFile.body"      ] && inFile="$inFile.body"
[ -e "$inFile.vertical"  ] && inFile="$inFile.vertical"
[ -e "$inFile.crunched"  ] && inFile="$inFile.crunched"
[ ! -e "$inFile" ] && echo "infile $inFile not found" && exit 1

outFile="$inFile.metad"

[ -e "$outFile" ] && echo "$outFile already exists, skipping metadata formatting" && exit 0

echo "reformatting metadata of $inFile"

# use these arrays as an inverted stack: new elements are pushed/popped at index 0, building a map of what xml tags have been opened and not closed
# element 0 is used for convenience, as $arr returns the 0th element of the array arr, and is more legible than ${arr[${#arr[@]} - 1]}
declare -a origTagNames=()
declare -a types=()
# push at 0: arr=("a" "${arr[@]}")
# pop at 0: arr=("${arr[@]:1}")

# make and clear tempFile
tempFile="$outFile.temp"
>"$tempFile"

while read -r line; do
  # skip lines without an xml tag
  if ! grep -q '[<>]' <<< "$line"; then
    echo "$line" >> "$tempFile"
    continue
  fi
  # skip glue tag
  if [ "$line" == "<g>" ]; then
    echo "$line" >> "$tempFile"
    continue
  fi

  # error check for sanity
  if [ "${#types[@]}" -ne "${#origTagNames[@]}" ]; then echo "stack sizes mismatch, types: ${types[@]}, origNames: ${origTagNames[@]}, exiting"; exit 1; fi

  [ ! -z $DEBUG_VERBOSE ] && echo "line in: $line"

  # if we're here, it's an xml tag
  # handle closing tags
  if grep -q "< */" <<< "$line"; then
    # trim tag name to remove leading, trailing spaces and <>
    tagName="`sed "s#< */ *##" <<< "$line"`"
    tagName="`sed "s# *>##" <<< "$tagName"`"

    [ ! -z $DEBUG_VERBOSE ] && echo "found closing tag $tagName"

    # close lower tags
    # loop until the tag stack is empty, or the tagName is found and break is called
    while [ ! -z "$types" ]; do
      [ ! -z $DEBUG_VERBOSE ] && echo "    closing $types, orig $origTagNames"

      # close the lowest tag in the array
      echo "</$types>" >> "$tempFile"
      # store the latest original tag name for comparisons
      latestOrig="$origTagNames"
      # remove the lowest element from both stacks
      origTagNames=("${origTagNames[@]:1}")
      types=("${types[@]:1}")
      # check if we've found the tag we're looking for
      [ "$latestOrig" == "$tagName" ] && break
      # check if we've closed a non-self-closing tag and warn if so
      [ "$latestOrig" != "SELF_CLOSING" ] && echo "warning: closing non-self-closing tag $tagName, types: ${types[@]}, origNames: ${origTagNames[@]}" >&2
    done
  else
    # handle opening or self-closing tags
    isSelfClosing=
    grep -q "/ *>" <<< "$line" && isSelfClosing=1
    # format: < *origName *(thing1="val\"ue1")* *>
    tagName="`grep -o "< *[^ >]*" <<< "$line"`"
    # trim tag name to remove leading < and spaces
    tagName="`sed "s#< *##g" <<< "$tagName"`"

    [ ! -z $DEBUG_VERBOSE ] && echo -n "found "
    [ ! -z $DEBUG_VERBOSE ] && [ -z $isSelfClosing ] && echo -n "opening tag "
    [ ! -z $DEBUG_VERBOSE ] && [ ! -z $isSelfClosing ] && echo -n "self-closing tag "
    [ ! -z $DEBUG_VERBOSE ] && echo "$tagName"
    # get type/unit
    # get all data (in the form name="value") into an array, including spaces and \"
    mapfile -t dataArray < <(grep -o '[^ =]*="\([^"]\|\\"\)*"' <<< "$line")
    # get the number to loop to
    arrayFinal="${#dataArray[@]}"
    (( arrayFinal-- ))
    # loop through the array, looking for type or unit
    type=
    unit=
    for i in `seq 0 $arrayFinal`; do
      data="${dataArray[i]}"
      if grep -q "type=" <<< "$data"; then
        # get the value of type
        type="`sed 's/^[^"]*"//' <<<"$data" | sed 's/"$//' | tr '[:upper:]' '[:lower:]'`" # in lowercase, to stop <book n=3><Book n=4>...
        # remove this element, so the rest of the array is just the data at the end
        unset dataArray[i]
      elif grep -q "unit=" <<< "$data"; then
        # get the value of unit
        unit="`sed 's/^[^"]*"//' <<<"$data" | sed 's/"$//' | tr '[:upper:]' '[:lower:]'`"
        # remove this element, so the rest of the array is just the data at the end
        unset dataArray[i]
      fi
    done
    # clear unit in case of duplicates
    [ "$type" == "$unit" ] && unit=
    # concatenate type and unit, this will be the new name of the tag

    [ ! -z $DEBUG_VERBOSE ] && echo "type $type, unit $unit, tagname $tagName"

    typeunit="$type$unit"
    # handle tag names to leave unmodified: quote, foreign, note, p
    if [[ " quote foreign note p " =~ " $tagName " ]]; then
      typeunit=
    fi
    # use the original tag string if typeunit is empty and it's not self-closing
    no_modify=
    [ -z "$typeunit$isSelfClosing" ] && no_modify=1
      # set typeunit to tagname for closing rest of tags if blank
    [ -z "$typeunit" ] && typeunit="$tagName"

    # check if there is a tag with the same typeunit open
    if [[ " ${types[@]} " =~ " $typeunit " ]]; then

      # close self-closing tags below and including that type/unit
      while [ ! -z "$types" ]; do
        [ "$origTagNames" != "SELF_CLOSING" ] && break # only close self-closing tags

        [ ! -z $DEBUG_VERBOSE ] && echo "    closing $types, orig $origTagNames"

        # close the lowest tag in the array
        echo "</$types>" >> "$tempFile"
        # store the latest original tag name for comparisons
        latestOrig="$origTagNames"
        # store the latest typeunit for comparison
        latestType="$types"
        # remove the lowest element from both stacks
        origTagNames=("${origTagNames[@]:1}")
        types=("${types[@]:1}")
        # check if we've found the tag we're looking for
        [ "$latestType" == "$typeunit" ] && break
      done
    fi
    # reformat opening tag and add to file
    if [ ! -z $no_modify ]; then

      [ ! -z $DEBUG_VERBOSE ] && echo "    writing unmodified tag $line"

      # write the original opening tag if no_modify is set
      echo "$line" >> "$tempFile"
    else
      [ ! -z $DEBUG_VERBOSE ] && echo "       typeunit $typeunit, dataArray ${dataArray[@]}, orig $tagName"
      [ ! -z $DEBUG_VERBOSE ] && echo "    writing modified tag <$typeunit ${dataArray[@]} orig=\"$tagName\">"

      # otherwise write the tag renamed and reformatted, as an opening tag
      # echo "<$typeunit ${dataArray[@]} orig=\"$tagName\">" >> "$tempFile"
      # don't include orig, as sketchEngine only allows 100 structures/data names, and these aren't useful
      echo "<$typeunit ${dataArray[@]}>" >> "$tempFile"
    fi
    # add the new tag to the stack
    types=("$typeunit" "${types[@]}")
    [ ! -z $isSelfClosing ] && tagName="SELF_CLOSING"
    origTagNames=("$tagName" "${origTagNames[@]}")
  fi
done < "$inFile"

# doing processing to temporary files, then renaming to outFile, means that outFile only exists in a finished state for interrupting/restarting processing
mv "$tempFile" "$outFile"
echo "done reformatting metadata of $outFile"
