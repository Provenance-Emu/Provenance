#!/bin/sh

./m64p_build.sh

mkdir -p mupen64plus.app/Contents/MacOS/

mv test/mupen64plus test/*.dylib mupen64plus.app/Contents/MacOS/

APP_CONTENTS="./mupen64plus.app/Contents"

FIX_LIST="-x $APP_CONTENTS/MacOS/mupen64plus \
 -x $APP_CONTENTS/MacOS/libmupen64plus.dylib \
 -x $APP_CONTENTS/MacOS/mupen64plus-audio-sdl.dylib \
 -x $APP_CONTENTS/MacOS/mupen64plus-input-sdl.dylib \
 -x $APP_CONTENTS/MacOS/mupen64plus-rsp-hle.dylib \
 -x $APP_CONTENTS/MacOS/mupen64plus-video-rice.dylib \
 -x $APP_CONTENTS/MacOS/mupen64plus-video-glide64mk2.dylib"
 
dylibbundler -od -b $FIX_LIST -d $APP_CONTENTS/libs/
 
rm -rf $APP_CONTENTS/Resources
rm -rf $APP_CONTENTS/SharedSupport
mkdir -p $APP_CONTENTS/Resources
mkdir -p $APP_CONTENTS/Frameworks
mv test/*.ini test/*.ttf $APP_CONTENTS/Resources
mv test/mupen* $APP_CONTENTS/Resources
mv test $APP_CONTENTS/SharedSupport

mv $APP_CONTENTS/SharedSupport/m64p_test_rom.v64 ./example.v64
echo './mupen64plus.app/Contents/MacOS/mupen64plus --corelib ./mupen64plus.app/Contents/MacOS/libmupen64plus.dylib --plugindir ./mupen64plus.app/Contents/MacOS --gfx mupen64plus-video-rice "$@"' > run_rice.sh
echo './mupen64plus.app/Contents/MacOS/mupen64plus --corelib ./mupen64plus.app/Contents/MacOS/libmupen64plus.dylib --plugindir ./mupen64plus.app/Contents/MacOS --gfx mupen64plus-video-glide64mk2 "$@"' > run_glide.sh
echo -e "Note that Mupen64Plus requires an Intel mac and will not run on PPC macs.\nIt is known to run on OS X 10.8; and most likely also runs on 10.7.\n\nThis application can NOT be opened in the Finder by double-clicking.\n To use, launch the terminal, then cd into the directory that contains mupen64plus.app and use a command like :\n\n    $ ./run_rice.sh  example.v64        # for the Rice video plugin\n    $ ./run_glide.sh  example.v64        # for the Glide64mk2 video plugin\n\n    Note that at this point, the only way to configure Mupen64Plus is to edit the config files in ~/.config/mupen64plus\n\n    If you cannot follow the instructions above then this package is not meant for you =)\n" > Readme.txt
chmod +x run_rice.sh run_glide.sh
CURDATE=`date +%Y%m%d`
zip -r mupen64plus-bundle-osx-$CURDATE.zip mupen64plus.app Readme.txt run_rice.sh run_glide.sh example.v64

