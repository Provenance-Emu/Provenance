//
//  ATR5200ControllerState.h
//  PVAtari800
//
//  Created by Joseph Mattiello on 1/20/19.
//  Copyright © 2019 Provenance Emu. All rights reserved.
//

@import Foundation;
@import PVSupport;

typedef struct ATR5200ControllerState {
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

extern int UI_is_active;
extern int UI_alt_function;
extern int UI_n_atari_files_dir;
extern int UI_n_saved_files_dir;
//extern char UI_atari_files_dir[UI_MAX_DIRECTORIES][FILENAME_MAX];
//extern char UI_saved_files_dir[UI_MAX_DIRECTORIES][FILENAME_MAX];
extern int PLATFORM_PORT(int num);
extern int UI_SelectCartType(int k);
