#!/bin/sh
#/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
# *   Mupen64plus - build_modules_src.sh                                    *
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
    echo "Usage: build_modules_src.sh <tag-name> <build-name>"
    exit 1
fi

modules='mupen64plus-core mupen64plus-rom mupen64plus-ui-console mupen64plus-audio-sdl mupen64plus-input-sdl mupen64plus-rsp-hle mupen64plus-video-rice mupen64plus-video-glide64mk2'
for modname in ${modules}; do
  echo "************************************ Downloading and packaging module source code: ${modname}"
  rm -rf "tmp"
  OUTPUTDIR="${modname}-$2"
  git clone --bare "https://github.com/mupen64plus/${modname}.git" "tmp"
  git --git-dir="$(pwd)/tmp/" archive --format=tar --prefix="${OUTPUTDIR}/" $1 | gzip -n --best > "${OUTPUTDIR}.tar.gz"
  rm -rf "tmp"
done
