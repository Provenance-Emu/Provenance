#!/bin/sh
#
# mupen64plus binary bundle uninstall script
#
# Copyright 2007-2014 The Mupen64Plus Development Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301, USA.
#

set -e

export PATH=/bin:/usr/bin

usage()
{
printf "usage: $(basename $0) [PREFIX] [SHAREDIR] [BINDIR] [LIBDIR] [PLUGINDIR] [MANDIR]
\tPREFIX    - installation directories prefix (default: /usr/local)
\tSHAREDIR  - path to Mupen64Plus shared data files (default: \$PREFIX/share/mupen64plus)
\tBINDIR    - path to Mupen64Plus binary program files (default: \$PREFIX/bin)
\tLIBDIR    - path to Mupen64Plus core library (default: \$PREFIX/lib)
\tPLUGINDIR - path to Mupen64Plus plugin libraries (default: \$PREFIX/lib/mupen64plus)
\tMANDIR    - path to manual files (default: \$PREFIX/man)
\tAPPSDIR   - path to install desktop file (default: \$PREFIX/share/applications)
\tICONSDIR  - path to install icon files (default: \$PREFIX/share/icons/hicolor)
"
}

if [ $# -gt 8 ]; then
	usage
	exit 1
fi

PREFIX="${1:-/usr/local}"
SHAREDIR="${2:-${PREFIX}/share/mupen64plus}"
BINDIR="${3:-${PREFIX}/bin}"
LIBDIR="${4:-${PREFIX}/lib}"
PLUGINDIR="${5:-${PREFIX}/lib/mupen64plus}"
MANDIR="${6:-${PREFIX}/share/man}"
APPSDIR="${7:-${PREFIX}/share/applications}"
ICONSDIR="${8:-${PREFIX}/share/icons/hicolor}"

# simple check for some permissions
if [ -d "${SHAREDIR}" -a ! -w "${SHAREDIR}" ]; then
	printf "Error: you do not have permission to uninstall from: ${SHAREDIR}\nMaybe you need to be root?\n"
	exit 1
fi
if [ -d "${BINDIR}" -a ! -w "${BINDIR}" ]; then
	printf "Error: you do not have permission to uninstall from: ${BINDIR}\nMaybe you need to be root?\n"
	exit 1
fi
if [ -d "${LIBDIR}" -a ! -w "${LIBDIR}" ]; then
	printf "Error: you do not have permission to uninstall from: ${LIBDIR}\nMaybe you need to be root?\n"
	exit 1
fi
if [ -d "${PLUGINDIR}" -a ! -w "${PLUGINDIR}" ]; then
	printf "Error: you do not have permission to uninstall from: ${PLUGINDIR}\nMaybe you need to be root?\n"
	exit 1
fi
if [ -d "${MANDIR}" -a ! -w "${MANDIR}" ]; then
	printf "Error: you do not have permission to uninstall from: ${MANDIR}\nMaybe you need to be root?\n"
	exit 1
fi
if [ -d "${APPSDIR}" -a ! -w "${APPSDIR}" ]; then
	printf "Error: you do not have permission to install at: ${APPSDIR}\nMaybe you need to be root?\n"
	exit 1
fi
if [ -d "${ICONSDIR}" -a ! -w "${ICONSDIR}" ]; then
	printf "Error: you do not have permission to install at: ${ICONSDIR}\nMaybe you need to be root?\n"
	exit 1
fi

printf "Uninstalling Mupen64Plus Binary Bundle from ${PREFIX}\n"
# Mupen64Plus-Core
rm -f "${LIBDIR}"/libmupen64plus.so*
/sbin/ldconfig
rm -f "${SHAREDIR}/font.ttf"
rm -f "${SHAREDIR}/mupencheat.txt"
rm -f "${SHAREDIR}/mupen64plus.ini"
rm -f "${SHAREDIR}"/doc/*
# Mupen64Plus-ROM
rm -f "${SHAREDIR}/m64p_test_rom.v64"
# Mupen64Plus-UI-Console
rm -f "${BINDIR}/mupen64plus"
rm -f "${MANDIR}/man6/mupen64plus.6"
rm -f "${APPSDIR}/mupen64plus.desktop"
rm -f "${ICONSDIR}/48x48/apps/mupen64plus.png"
rm -f "${ICONSDIR}/scalable/apps/mupen64plus.svg"
# Plugins
rm -f "${PLUGINDIR}/mupen64plus-audio-sdl.so"
rm -f "${PLUGINDIR}/mupen64plus-input-sdl.so"
rm -f "${PLUGINDIR}/mupen64plus-rsp-hle.so"
rm -f "${PLUGINDIR}/mupen64plus-video-rice.so"
rm -f "${PLUGINDIR}/mupen64plus-video-glide64mk2.so"
rm -f "${SHAREDIR}/RiceVideoLinux.ini"
rm -f "${SHAREDIR}/InputAutoCfg.ini"
rm -f "${SHAREDIR}/Glide64mk2.ini"
# get rid of the empty dirs
# ignore directories if they are really symbolic links
[ ! -L "${SHAREDIR}/doc" ] && rmdir --ignore-fail-on-non-empty "${SHAREDIR}/doc"
[ ! -L "${SHAREDIR}" ] && rmdir --ignore-fail-on-non-empty "${SHAREDIR}"
[ ! -L "${BINDIR}" ] && rmdir --ignore-fail-on-non-empty "${BINDIR}"
[ ! -L "${LIBDIR}" ] && rmdir --ignore-fail-on-non-empty "${LIBDIR}"
[ ! -L "${PLUGINDIR}" ] && rmdir --ignore-fail-on-non-empty "${PLUGINDIR}"
[ ! -L "${MANDIR}/man6" ] && rmdir --ignore-fail-on-non-empty "${MANDIR}/man6"
[ ! -L "${MANDIR}" ] && rmdir --ignore-fail-on-non-empty "${MANDIR}"
[ ! -L "${APPSDIR}" ] && rmdir --ignore-fail-on-non-empty "${APPSDIR}"
[ ! -L "${ICONSDIR}" ] && rmdir --ignore-fail-on-non-empty "${ICONSDIR}"

printf "Uninstall successful.\n"

