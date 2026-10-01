// Provenance build glue: SwiftPM treats any target containing a file named main.*
// as an executable target, so upstream's src/wswan/main.cpp is compiled through
// this differently named wrapper instead of being renamed inside the submodule.
#include "../mednafen-src/src/wswan/main.cpp"
