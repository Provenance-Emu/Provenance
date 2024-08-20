#!/bin/bash
VERSION=`head -n 1 mednafen/Documentation/modules.def`

cd build9x && \
cp src/mednafen.exe . && \
i486-w64-mingw32-strip mednafen.exe && \
i486-w64-mingw32-strip libcharset-1.dll libiconv-2.dll && \
mkdir -p de/LC_MESSAGES ru/LC_MESSAGES && \
cp ../mednafen/po/de.gmo de/LC_MESSAGES/mednafen.mo && \
cp ../mednafen/po/ru.gmo ru/LC_MESSAGES/mednafen.mo && \
7za a -mtc- -mx9 -mfb=258 -mpass=15 ../mednafen-"$VERSION"-win9x.zip mednafen.exe libgcc_s_dw2-1.dll libcharset-1.dll libiconv-2.dll de/ ru/ && \
cd ../mednafen && \
7za a -mtc- -mx9 -mfb=258 -mpass=15 ../mednafen-"$VERSION"-win9x.zip COPYING ChangeLog Documentation/*.html Documentation/*.css Documentation/*.png Documentation/*.txt && \
cd .. && \
#
#
#
echo "Done."

