#!/bin/sh

#gettextize --force --copy --intl
autoheader
aclocal -I m4
autoconf -W syntax,cross
automake -a -c -f

rm autom4te.cache/*
rmdir autom4te.cache
