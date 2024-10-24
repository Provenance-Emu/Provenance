// Copyright 2020 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.


#import <dlfcn.h>
#import <stdio.h>
#import <unistd.h>

bool IsProcessDebugged(void);
bool SetProcessDebuggedWithPTrace(void);
