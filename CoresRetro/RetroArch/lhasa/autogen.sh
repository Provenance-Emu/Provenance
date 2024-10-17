#!/bin/sh

mkdir -p autotools

libtoolize || glibtoolize
aclocal
autoheader
automake -a 
autoconf
automake -a

./configure $@
