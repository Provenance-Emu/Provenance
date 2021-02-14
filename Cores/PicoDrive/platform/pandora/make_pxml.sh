#!/bin/sh
set -e

verfile=../common/version.h
test -f $verfile

major=`head -n 1 $verfile | sed 's/.*"\([0-9]*\)\.\([0-9]*\).*/\1/g'`
minor=`head -n 1 $verfile | sed 's/.*"\([0-9]*\)\.\([0-9]*\).*/\2/g'`
# lame, I know..
build=`git describe HEAD | grep -- - | sed -e 's/.*\-\(.*\)\-.*/\1/'`
test -n "$build" || build=0

trap "rm -f $2" ERR

sed 's/@major@/'$major'/' "$1" > "$2"
sed -i 's/@minor@/'$minor'/' "$2"
sed -i 's/@build@/'$build'/' "$2"
