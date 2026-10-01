// Provenance build glue: compile upstream's C font table as C++.
// It includes <mednafen/types.h>, which is C++-only, and SwiftPM cannot force a
// .c file through the C++ compiler, so the upstream file is included here rather
// than renamed inside the mednafen-git submodule.
#include "../mednafen-src/src/video/font-data-12x13.c"
