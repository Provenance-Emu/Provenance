#!/bin/sh

if [ "$1" = "" ]; then
	mednafen_version=`head -n1 mednafen/Documentation/modules.def`
else
	mednafen_version="$1"
fi
mednafen_tarball="mednafen-$mednafen_version.tar.xz"
git -C mednafen archive --format=tar --prefix=mednafen/ HEAD^{tree} | xz > "$mednafen_tarball"
