#!/bin/sh

autoheader
aclocal -I m4
autoconf -W syntax,cross
automake -a -c

rm autom4te.cache/*
rmdir autom4te.cache

