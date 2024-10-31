#!/bin/bash

# Generate Localizable.strings
find -E . -iregex '.*\.(m|h|mm)$' \
    -not -path "./Tests*" \
    -print0 \
| xargs -0 genstrings -o Resources/en.lproj

# Define file and temp file
LOCALIZE=./Resources/en.lproj/UnrarKit.strings
UTF8=./Resources/en.lproj/UnrarKitUTF8.txt

# Convert file encoding from UTF-16 to UTF-8
iconv -f UTF-16LE -t UTF-8 $LOCALIZE >$UTF8
mv $UTF8 $LOCALIZE

# Replace all \\n tokens in the file with a newline (used in comments)
sed -i "" 's_\\\\n_\
_g' $LOCALIZE

# Check for missing comments in the UTF8 file, showing the violating lines
MISSING=$(grep -A 1 'engineer' $LOCALIZE | sed '/*\/$/ s_.*__')

# If there were missing comments
if [ -n "$MISSING" ]; then
	echo "Comments are missing for:"

	#Print output, putting line breaks back in and indenting each line
	echo $MISSING  | sed 's:-- :\
:' | sed 's/^/&   /g'

	# Return non-zero to signal an error
	exit 1
fi