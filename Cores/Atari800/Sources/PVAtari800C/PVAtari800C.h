//
//  PVAtari800C.h
//
//
//  Created by Joseph Mattiello on 5/27/24.
//

#ifndef PVAtari800C_h
#define PVAtari800C_h

// ataria800 project includes
#include "afile.h"
#include "akey.h"
#include "antic.h"
#include "atari.h"
#include "cartridge.h"
#include "cassette.h"
#include "cfg.h"
#include "colours.h"
#include "colours_ntsc.h"
#include "config.h"
#include "devices.h"
#include "gtia.h"
#include "ide.h"
#include "input.h"
#include "memory.h"
#include "pbi.h"
#include "pia.h"
#include "platform.h"
#include "pokey.h"
#include "pokeysnd.h"
#include "rtime.h"
#include "sio.h"
#include "sound.h"
#include "statesav.h"
#include "sysrom.h"
#include "ui.h"

int UI_is_active = FALSE;
int UI_alt_function = -1;
int UI_n_atari_files_dir = 0;
int UI_n_saved_files_dir = 0;
char UI_atari_files_dir[UI_MAX_DIRECTORIES][FILENAME_MAX];
char UI_saved_files_dir[UI_MAX_DIRECTORIES][FILENAME_MAX];

typedef struct {
    int up;
    int down;
    int left;
    int right;
    int fire;
    int fire2;
    int start;
    int pause;
    int reset;
} ATR5200ControllerState;

#endif /* PVAtari800C_h */
