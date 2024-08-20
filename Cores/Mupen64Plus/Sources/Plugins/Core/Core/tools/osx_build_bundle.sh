#!/bin/sh

./m64p_build.sh

APP_CONTENTS="./mupen64plus.app/Contents"

rm -rf $APP_CONTENTS
mkdir -p $APP_CONTENTS/MacOS/
mkdir -p $APP_CONTENTS/Frameworks/

mv test/mupen64plus $APP_CONTENTS/MacOS/
mv test/*.dylib $APP_CONTENTS/Frameworks/

FIX_LIST="-x $APP_CONTENTS/MacOS/mupen64plus \
 -x $APP_CONTENTS/Frameworks/libmupen64plus.dylib \
 -x $APP_CONTENTS/Frameworks/mupen64plus-audio-sdl.dylib \
 -x $APP_CONTENTS/Frameworks/mupen64plus-input-sdl.dylib \
 -x $APP_CONTENTS/Frameworks/mupen64plus-rsp-hle.dylib \
 -x $APP_CONTENTS/Frameworks/mupen64plus-video-rice.dylib \
 -x $APP_CONTENTS/Frameworks/mupen64plus-video-glide64mk2.dylib"
 
dylibbundler -of -b $FIX_LIST -p @executable_path/../Frameworks/ -d $APP_CONTENTS/Frameworks/
 
mkdir -p $APP_CONTENTS/Resources
mv test/*.ini test/*.ttf $APP_CONTENTS/Resources
mv test/mupen* $APP_CONTENTS/Resources
mv test $APP_CONTENTS/SharedSupport

mv $APP_CONTENTS/SharedSupport/m64p_test_rom.v64 ./example.v64
echo './mupen64plus.app/Contents/MacOS/mupen64plus --gfx mupen64plus-video-rice "$@"' > run_rice.sh
echo './mupen64plus.app/Contents/MacOS/mupen64plus --gfx mupen64plus-video-glide64mk2 "$@"' > run_glide.sh
echo "Note that Mupen64Plus requires an Intel mac and will not run on PPC macs.\nIt also requires OS X 10.9 or later.\n\nThis application can NOT be opened in the Finder by double-clicking.\n To use, launch the terminal, then cd into the directory that contains mupen64plus.app and use a command like :\n\n    $ ./run_rice.sh  example.v64        # for the Rice video plugin\n    $ ./run_glide.sh  example.v64        # for the Glide64mk2 video plugin\n\n    Note that at this point, the only way to configure Mupen64Plus is to edit the config files in ~/Library/Application Support/Mupen64Plus/\n\n" > Readme.txt
chmod +x run_rice.sh run_glide.sh
CURDATE=`date +%Y%m%d`
zip -r mupen64plus-bundle-osx-$CURDATE.zip mupen64plus.app Readme.txt run_rice.sh run_glide.sh example.v64

