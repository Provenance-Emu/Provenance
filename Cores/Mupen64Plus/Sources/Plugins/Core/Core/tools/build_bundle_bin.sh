#!/bin/sh
#/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
# *   Mupen64plus - build_bundle_bin.sh                                     *
# *   Mupen64Plus homepage: https://mupen64plus.org/                        *
# *   Copyright (C) 2009-2013 Richard Goedeken                              *
# *                                                                         *
# *   This program is free software; you can redistribute it and/or modify  *
# *   it under the terms of the GNU General Public License as published by  *
# *   the Free Software Foundation; either version 2 of the License, or     *
# *   (at your option) any later version.                                   *
# *                                                                         *
# *   This program is distributed in the hope that it will be useful,       *
# *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
# *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
# *   GNU General Public License for more details.                          *
# *                                                                         *
# *   You should have received a copy of the GNU General Public License     *
# *   along with this program; if not, write to the                         *
# *   Free Software Foundation, Inc.,                                       *
# *   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.          *
# * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

# terminate the script if any commands return a non-zero error code
set -e

if [ $# -lt 2 ]; then
    echo "Usage: build_bundle_bin.sh <tag-name> <build-name> [<makefile_param> ...]"
    exit 1
fi

TEMPDIR="mupen64plus-temp-build"

rm -rf ${TEMPDIR}
mkdir -p ${TEMPDIR}/source
cd ${TEMPDIR}/source

echo "************************************ Downloading Mupen64Plus module source code"
git clone --branch $1 https://github.com/mupen64plus/mupen64plus-core.git
git clone --branch $1 https://github.com/mupen64plus/mupen64plus-rom.git
git clone --branch $1 https://github.com/mupen64plus/mupen64plus-ui-console.git
git clone --branch $1 https://github.com/mupen64plus/mupen64plus-audio-sdl.git
git clone --branch $1 https://github.com/mupen64plus/mupen64plus-input-sdl.git
git clone --branch $1 https://github.com/mupen64plus/mupen64plus-rsp-hle.git
git clone --branch $1 https://github.com/mupen64plus/mupen64plus-video-rice.git
git clone --branch $1 https://github.com/mupen64plus/mupen64plus-video-glide64mk2.git
shift
for dirname in ./mupen64plus-*; do rm -rf ${dirname}/.git*; done

OUTPUTDIR="mupen64plus-bundle-$1"
shift

echo "************************************ Building Mupen64Plus modules"
cd ..
tar xzvf source/mupen64plus-core/tools/m64p_helper_scripts.tar.gz

./m64p_build.sh COREDIR=/usr/local/lib/ $@
mv "test" "${OUTPUTDIR}"

echo "************************************ Creating archive"
cp source/mupen64plus-core/tools/install_binary_bundle.sh "${OUTPUTDIR}/install.sh"
cp source/mupen64plus-core/tools/uninstall_binary_bundle.sh "${OUTPUTDIR}/uninstall.sh"

tar c "${OUTPUTDIR}" --owner 0 --group 0 --numeric-owner | gzip -n > "../${OUTPUTDIR}.tar.gz"
cd ..
rm -rf "${TEMPDIR}"
