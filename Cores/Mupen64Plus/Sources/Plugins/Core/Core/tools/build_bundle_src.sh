#!/bin/sh
#/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
# *   Mupen64plus - build_bundle_src.sh                                     *
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
    echo "Usage: build_bundle_src.sh <tag-name> <build-name>"
    exit 1
fi

OUTPUTDIR="mupen64plus-bundle-$2"

echo "************************************ Creating directory: " ${OUTPUTDIR}
rm -rf ${OUTPUTDIR}
mkdir -p ${OUTPUTDIR}/source
cd ${OUTPUTDIR}/source

echo "************************************ Downloading Mupen64Plus module source code"
git clone --branch $1 https://github.com/mupen64plus/mupen64plus-core.git
git clone --branch $1 https://github.com/mupen64plus/mupen64plus-rom.git
git clone --branch $1 https://github.com/mupen64plus/mupen64plus-ui-console.git
git clone --branch $1 https://github.com/mupen64plus/mupen64plus-audio-sdl.git
git clone --branch $1 https://github.com/mupen64plus/mupen64plus-input-sdl.git
git clone --branch $1 https://github.com/mupen64plus/mupen64plus-rsp-hle.git
git clone --branch $1 https://github.com/mupen64plus/mupen64plus-video-rice.git
git clone --branch $1 https://github.com/mupen64plus/mupen64plus-video-glide64mk2.git
for dirname in ./mupen64plus-*; do rm -rf ${dirname}/.git*; done

# unzip the helper scripts and remove the Mercurial scripts
cd ..
tar xzvf source/mupen64plus-core/tools/m64p_helper_scripts.tar.gz
rm -f m64p_get.sh m64p_update.sh

echo "************************************ Creating archive"
cd ..
tar c "${OUTPUTDIR}" --owner 0 --group 0 --numeric-owner | gzip -n > "${OUTPUTDIR}.tar.gz"
rm -rf "${OUTPUTDIR}"


