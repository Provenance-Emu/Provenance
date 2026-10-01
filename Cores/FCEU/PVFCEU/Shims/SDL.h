// Provenance shim for fceux's core build.
//
// Outside the Windows and Qt drivers, fceux/src/fceu.cpp includes
// "drivers/sdl/sdl.h", which starts with #include <SDL.h>. The core only uses
// that header for driver declarations that need no SDL types (dendy,
// pal_emulation, swapDuty, LoadGame, ...), so this empty header satisfies the
// include without linking SDL. Only the `fceux` target has this directory on
// its header search path.
#pragma once
