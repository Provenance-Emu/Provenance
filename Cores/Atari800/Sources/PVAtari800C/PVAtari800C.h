//
//  PVAtari800C.h
//
//
//  Created by Joseph Mattiello on 5/27/24.
//

#ifndef PVAtari800C_h
#define PVAtari800C_h

@import libatari800;
//#include <ui.h>

int UI_is_active;
int UI_alt_function;
int UI_n_atari_files_dir;
int UI_n_saved_files_dir;
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
