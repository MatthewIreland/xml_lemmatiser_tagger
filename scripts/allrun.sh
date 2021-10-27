inFile="$1"
[ ! -e "$inFile" ] && echo "infile $inFile not found" && exit 1

scripts/1_splitHeaderBody.sh "$inFile"

# is the file in unicode or betacode?
if grep -q "[αβγδεϝζηθικλμνξοπρσςϲτυφχψω]" "$inFile"; then
  scripts/2_verticaliseBody.sh -u "$inFile"
else
  scripts/2_verticaliseBody.sh "$inFile"
fi

# is the file in unicode or betacode?
if grep -q "[αβγδεϝζηθικλμνξοπρσςϲτυφχψω]" "$inFile"; then
  scripts/3_crunch.sh -u "$inFile"
else
  scripts/3_crunch.sh "$inFile"
fi

scripts/4_reformatMetadata.sh "$inFile"

scripts/5_formatHeader.sh "$inFile"
