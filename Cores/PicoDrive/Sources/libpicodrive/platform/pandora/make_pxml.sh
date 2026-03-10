#!/bin/bash
set -e

verfile=../common/version.h
test -f $verfile

major=`head -n 1 $verfile | sed 's/[^0-9]*\([0-9]*\)\.\([0-9]*\).*/\1/g'`
minor=`head -n 1 $verfile | sed 's/[^0-9]*\([0-9]*\)\.\([0-9]*\).*/\2/g'`
# lame, I know..
build=`git describe HEAD | grep -- - | sed -e 's/.*\-\(.*\)\-.*/\1/'`
test -n "$build" && build_post="-$build"
test -n "$build" || build=0

trap "rm -f $2" ERR

sed -e 's/@major@/'$major'/' \
    -e 's/@minor@/'$minor'/' \
    -e 's/@build@/'$build'/' \
    -e 's/@build_post@/'$build_post'/' \
	"$1" > "$2"
