//
//  PokeMiniC.h
//
//
//  Created by Joseph Mattiello on 5/27/24.
//

#ifndef PokeMiniC_h
#define PokeMiniC_h

#if __has_include(<AudioToolbox/AudioToolbox.h>)
#import <AudioToolbox/AudioToolbox.h>
#endif
@import libpokemini;

extern int OpenEmu_KeysMapping[10];

typedef struct {
    bool a;
    bool b;
    bool c;
    bool up;
    bool down;
    bool left;
    bool right;
    bool menu;
    bool power;
    bool shake;
} PokeMFiState;


#endif /* PokeMiniC_h */
