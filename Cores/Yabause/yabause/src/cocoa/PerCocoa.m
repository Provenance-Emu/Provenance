/*  Copyright 2010, 2011 Lawrence Sebald

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include "PerCocoa.h"
#include "yabause.h"

#include <AppKit/NSEvent.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSString.h>

/* Forward Declarations. */
static int PERCocoaInit(void);
static void PERCocoaDeInit(void);
static int PERCocoaHandleEvents(void);

static u32 PERCocoaScan(u32 flags);
static void PERCocoaFlush(void);
static void PERCocoaKeyName(u32 key, char *name, int size);

static PerPad_struct *c1 = NULL, *c2 = NULL;

PerInterface_struct PERCocoa = {
    PERCORE_COCOA,
    "Cocoa Keyboard Input Interface",
    &PERCocoaInit,
    &PERCocoaDeInit,
    &PERCocoaHandleEvents,
    &PERCocoaScan,
    0,
    &PERCocoaFlush,
    &PERCocoaKeyName
};

/* Utility function to check if everything's set up right for a port */
static BOOL AllSetForPort(int p) {
    int i;
    NSString *str;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    id val;
    Class c = [NSNumber class];

    for(i = 0; i < 13; ++i) {
        str = [NSString stringWithFormat:@"Keyboard %d %s", p, PerPadNames[i]];
        val = [d objectForKey:str];

        if(!val || ![val isKindOfClass:c]) {
            return NO;
        }
    }

    return YES;
}

void PERCocoaSetKey(u32 key, u8 n, int p) {
    PerPad_struct *c;
    NSString *str;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSNumber *val = [NSNumber numberWithUnsignedInt:(unsigned int)key];

    assert(n <= PERPAD_Z);

    /* Build the string we'll look for, and set the value for that key */
    str = [NSString stringWithFormat:@"Pad %d %s", p, PerPadNames[n]];
    [d setObject:val forKey:str];
    [d synchronize];

    /* Update the mapping if we're running */
    if(p == 0) {
        c = c1;
    }
    else {
        c = c2;
    }

    /* This will effectively make sure we don't update until we've started. */
    if(c) {
        PerSetKey(key, n, c);
    }
}

u32 PERCocoaGetKey(u8 n, int p) {
    NSString *str;
    id result;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];

    assert(n <= PERPAD_Z);

    /* Fetch the key data */
    str = [NSString stringWithFormat:@"Pad %d %s", p, PerPadNames[n]];
    result = [d objectForKey:str];

    if(result && [result isKindOfClass:[NSNumber class]]) {
        return (u32)[result unsignedIntValue];
    }
    else {
        return (u32)-1;
    }
}
static int PERCocoaInit(void) {
    /* Fill in pad 1 */
    c1 = PerPadAdd(&PORTDATA1);

    PerSetKey(PERCocoaGetKey(PERPAD_UP, 0), PERPAD_UP, c1);
    PerSetKey(PERCocoaGetKey(PERPAD_DOWN, 0), PERPAD_DOWN, c1);
    PerSetKey(PERCocoaGetKey(PERPAD_LEFT, 0), PERPAD_LEFT, c1);
    PerSetKey(PERCocoaGetKey(PERPAD_RIGHT, 0), PERPAD_RIGHT, c1);
    PerSetKey(PERCocoaGetKey(PERPAD_LEFT_TRIGGER, 0), PERPAD_LEFT_TRIGGER, c1);
    PerSetKey(PERCocoaGetKey(PERPAD_RIGHT_TRIGGER, 0), PERPAD_RIGHT_TRIGGER, c1);
    PerSetKey(PERCocoaGetKey(PERPAD_START, 0), PERPAD_START, c1);
    PerSetKey(PERCocoaGetKey(PERPAD_A, 0), PERPAD_A, c1);
    PerSetKey(PERCocoaGetKey(PERPAD_B, 0), PERPAD_B, c1);
    PerSetKey(PERCocoaGetKey(PERPAD_C, 0), PERPAD_C, c1);
    PerSetKey(PERCocoaGetKey(PERPAD_X, 0), PERPAD_X, c1);
    PerSetKey(PERCocoaGetKey(PERPAD_Y, 0), PERPAD_Y, c1);
    PerSetKey(PERCocoaGetKey(PERPAD_Z, 0), PERPAD_Z, c1);

    /* Fill in pad 2 */
    c2 = PerPadAdd(&PORTDATA2);

    PerSetKey(PERCocoaGetKey(PERPAD_UP, 1), PERPAD_UP, c2);
    PerSetKey(PERCocoaGetKey(PERPAD_DOWN, 1), PERPAD_DOWN, c2);
    PerSetKey(PERCocoaGetKey(PERPAD_LEFT, 1), PERPAD_LEFT, c2);
    PerSetKey(PERCocoaGetKey(PERPAD_RIGHT, 1), PERPAD_RIGHT, c2);
    PerSetKey(PERCocoaGetKey(PERPAD_LEFT_TRIGGER, 1), PERPAD_LEFT_TRIGGER, c2);
    PerSetKey(PERCocoaGetKey(PERPAD_RIGHT_TRIGGER, 1), PERPAD_RIGHT_TRIGGER, c2);
    PerSetKey(PERCocoaGetKey(PERPAD_START, 1), PERPAD_START, c2);
    PerSetKey(PERCocoaGetKey(PERPAD_A, 1), PERPAD_A, c2);
    PerSetKey(PERCocoaGetKey(PERPAD_B, 1), PERPAD_B, c2);
    PerSetKey(PERCocoaGetKey(PERPAD_C, 1), PERPAD_C, c2);
    PerSetKey(PERCocoaGetKey(PERPAD_X, 1), PERPAD_X, c2);
    PerSetKey(PERCocoaGetKey(PERPAD_Y, 1), PERPAD_Y, c2);
    PerSetKey(PERCocoaGetKey(PERPAD_Z, 1), PERPAD_Z, c2);

    return 0;
}

static void PERCocoaDeInit(void) {
}

static int PERCocoaHandleEvents(void) {
    return YabauseExec();
}

static u32 PERCocoaScan(u32 flags) {
    return 0;
}

static void PERCocoaFlush(void) {
}

static void PERCocoaKeyName(u32 key, char *name, int size)    {
    snprintf(name, size, "%x", (unsigned int)key);
}
