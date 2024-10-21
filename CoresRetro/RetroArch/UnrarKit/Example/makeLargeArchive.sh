#!/bin/bash


UNCOMPRESSED_FILE="$1"
ARCHIVE_NAME="`dirname $1`/large-archive.rar"

ARCH="`uname -m`"

if [[ $ARCH -eq "arm64" ]];
then
  RAR="Tests/Test Data/bin/arm/rar"
else
  RAR="Tests/Test Data/bin/x64/rar"
fi

"$RAR" a -ep "${ARCHIVE_NAME}" "${UNCOMPRESSED_FILE}"