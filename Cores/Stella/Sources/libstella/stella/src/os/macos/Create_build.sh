#!/bin/sh
#
# Creates a Stella disk image (dmg) from the command line.
# usage:
#    Create_build.sh <version>
#
# The result will be a file called ~/Desktop/Stella-<ver>-macos.dmg

if [ $# != 1 ]; then
	echo "usage: Create_build.sh version"
	exit 0
fi

VER="$1"
DMG="Stella-${VER}-macos.dmg"
DISK="/Volumes/Stella"
DEST=~/Desktop/${DMG}

echo "Creating ${DMG} file ..."
gunzip -c template.dmg.gz > "${DMG}"

echo "Mounting ${DMG} file ..."
hdiutil attach "${DMG}"

echo "Copying documentation ..."
ditto ../../Announce.txt ../../Changes.txt ../../Copyright.txt ../../License.txt ../../README.md ../../Todo.txt "${DISK}"

echo "Copying application ..."
cp -r DerivedData/Build/Products/Release/Stella.app "${DISK}"

echo "Updating modification times ..."
touch "${DISK}"/Stella.app "${DISK}"/*.txt

echo "Ejecting ${DMG} ..."
hdiutil eject "${DISK}"

if [ -f "${DEST}" ]; then
	echo "Removing duplicate image found on desktop ..."
  rm -f "${DEST}"
fi

echo "Compressing image, moving to Desktop ..."
hdiutil convert "${DMG}" -format UDZO -imagekey zlib-level=9 -o "${DEST}"
rm -f "${DMG}"
