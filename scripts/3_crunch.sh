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
[ -e "$inFile.vertical" ] && inFile="$inFile.vertical"
[ ! -e "$inFile" ] && echo "infile $inFile not found" && exit 1

outFile="$inFile.crunched"

[ -e "$outFile" ] && echo "$outFile already exists, skipping crunching" && exit 0

[ ! -z "$already_unicode" ] && echo "crunching $inFile as unicode" || echo "crunching $inFile as beta-code"

start_time=$SECONDS

punctuations="[.,:;_#-]"
[ ! -z $already_unicode ] && punctuations="[][()†“”‘’&·—ʹ.,:;_#-]"

# create crunchErrors if it does not exist
[ ! -e crunchErrors ] && touch crunchErrors

# handle english-language notes in greek text, with greek quotes, using these variables
inNoteTag=
inForeignTag=

# these variables are for displaying progress
lengthTotal=`wc -l "$inFile"`
lengthDone=0

# make and clear tempFile
tempFile="$outFile.temp"
>"$tempFile"

# loop through line by line
while read -r line; do
  (( lengthDone ++ ))
  (( lengthDone % 1000 == 0 )) && echo "crunching [$lengthDone of $lengthTotal] $inFile"
  # check for xml tags
  if grep -q '[<>]' <<< "$line"; then
    # check for self-closing tags
    if grep -q '/>' <<< "$line"; then
      # skip crunching
      echo "$line" >> "$tempFile"
      continue
    fi
    # if we are here, it is an opening or closing tag: check for note and foreign tags
    if [ -z $inNoteTag ]; then
      # not in note tag
      if grep -q '<note .*>' <<< "$line"; then
        inNoteTag=1
        inForeignTag=
      fi
    else
      # in note tag
      if grep -q '</note' <<< "$line"; then
        inNoteTag=
        inForeignTag=
      # look for foreign tags with gr, gk etc to avoid selecting <foreign lang="Italian"> as greek
    elif grep -q '<foreign [^>]*[gG][rRkK].*>' <<< "$line"; then
        inForeignTag=1
      elif grep -q '</foreign' <<< "$line"; then
        inForeignTag=
      fi
    fi
    # skip crunching
    echo "$line" >> "$tempFile"
    continue
  fi

  # check for sequences like &lpar;
  if grep -q "&" <<< "$line"; then
    case "$line" in
      "&lpar;")   line="(";;
      "&rpar;")   line=")";;
      "&lt;")     line="<";;
      "&gt;")     line=">";;
      "&mdash;")  line="—";;
      "&dagger;") line="†";;
      "&lsqb;")   line="[";;
      "&rsqb;")   line="]";;
      "&ldquo;")  line="“";;
      "&rdquo;")  line="”";;
      "&lsquo;")  line="‘";;
      "&rsquo;")  line="’";;
      "&amp;")    line="&";;
      *) ;;
    esac
    echo "$line" >> "$tempFile"
    # don't further process punctuation
    continue
  fi

  # check if line is punctuation
  if grep -q "$punctuations" <<< "$line"; then
    # skip crunching
		if [ -z $already_unicode ]; then
			# not already unicode, convert
	    beta2uni <<< "$line" >> "$tempFile"
		else
			# already unicode, don't convert
			echo "$line" >> "$tempFile"
		fi
    continue
  fi

  if [ ! -z $inNoteTag ] && [ -z $inForeignTag ]; then
    # if we are in a note tag and not in a foreign tag, it's an english word so skip crunching
    echo "$line" >> "$tempFile"
    continue
  fi

  # if we've got here, it's an actual greek word
  word="$line"
  analysis=$(
      . /home/matthew/victoria/linguini/scripts/venv/bin/activate
      python /home/matthew/victoria/linguini/scripts/perseus_query.py "$word"
  )
 
  echo "$analysis" >> $outFile

done < "$inFile"

# doing processing to temporary files, then renaming to outFile, means that outFile only exists in a finished state for interrupting/restarting processing
mv "$tempFile" "$outFile"
echo "done crunching $outFile"

elapsed=$(( SECONDS - start_time ))
eval "echo Time taken: $(date -ud "@$elapsed" +'$((%s/3600/24)) days %H hr %M min %S sec')"
