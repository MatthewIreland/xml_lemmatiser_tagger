inFile="$1"
[ ! -e $inFile ] && echo "infile $inFile not found" && exit 1
[ -e "$inFile.vert" ] && echo "$inFile.vert already exists, skipping" && exit 0
scripts/1_splitHeaderBody.sh $inFile
scripts/2_verticaliseBody.sh $inFile
scripts/3_crunch.sh $inFile
scripts/4_formatHeader.sh $inFile
# rm $inFile.header
# rm $inFile.body*
