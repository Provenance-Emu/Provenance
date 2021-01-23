/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _CROSSHAIRS_H_
#define _CROSSHAIRS_H_

// Read in the specified crosshair file, replacing whatever data might be in that slot.
// Available slots are 1-31.
// The input file must be a PNG or a text file. 
// PNG:  15x15 pixels, palettized, with 3 colors (white, black, and transparent).
// text: 15 lines of 16 characters (counting the \n), consisting of ' ', '#', or '.'.

bool S9xLoadCrosshairFile (int idx, const char *filename);

// Return the specified crosshair. Woo-hoo.
// char * to a 225-byte string, with '#' marking foreground, '.' marking background,
// and anything else transparent.

const char * S9xGetCrosshair (int idx);

// In controls.cpp. Sets the crosshair for the specified device. Defaults are:
//                cross   fgcolor    bgcolor
//   Mouse 1:       1     White      Black
//   Mouse 2:       1     Purple     White
//   Superscope:    2     White      Black
//   Justifier 1:   4     Blue       Black
//   Justifier 2:   4     MagicPink  Black
//   Macs Rifle:    2     White      Black
//
// Available colors are: Trans, Black, 25Grey, 50Grey, 75Grey, White, Red, Orange,
// Yellow, Green, Cyan, Sky, Blue, Violet, MagicPink, and Purple.
// You may also prefix a 't' (e.g. tBlue) for a 50%-transparent version.
// Use idx = -1 or fg/bg = NULL to keep the current setting.

enum crosscontrols
{
	X_MOUSE1,
	X_MOUSE2,
	X_SUPERSCOPE,
	X_JUSTIFIER1,
	X_JUSTIFIER2,
	X_MACSRIFLE
};

void S9xSetControllerCrosshair (enum crosscontrols ctl, int8 idx, const char *fg, const char *bg);
void S9xGetControllerCrosshair (enum crosscontrols ctl, int8 *idx, const char **fg, const char **bg);

// In gfx.cpp, much like S9xDisplayChar() except it takes the parameters
// listed and looks up GFX.Screen.
// The 'crosshair' arg is a 15x15 image, with '#' meaning fgcolor,
// '.' meaning bgcolor, and anything else meaning transparent.
// Color values should be (RGB):
//  0 = transparent  4 = 23 23 23    8 = 31 31  0   12 =  0  0 31
//  1 =  0  0  0     5 = 31 31 31    9 =  0 31  0   13 = 23  0 31
//  2 =  8  8  8     6 = 31  0  0   10 =  0 31 31   14 = 31  0 31
//  3 = 16 16 16     7 = 31 16  0   11 =  0 23 31   15 = 31  0 16
//  16-31 are 50% transparent versions of 0-15.

void S9xDrawCrosshair (const char *crosshair, uint8 fgcolor, uint8 bgcolor, int16 x, int16 y);

#endif
