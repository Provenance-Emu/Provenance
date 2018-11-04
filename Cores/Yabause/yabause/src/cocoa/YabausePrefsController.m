/*  Copyright 2010 Lawrence Sebald

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

#include <ctype.h>

#include "YabausePrefsController.h"

#include "cs0.h"
#include "vidogl.h"
#include "vidsoft.h"
#include "scsp.h"
#include "smpc.h"
#include "sndmac.h"
#include "PerCocoa.h"

@implementation YabausePrefsController

- (void)awakeFromNib
{
    _cartType = CART_NONE;
    _region = REGION_AUTODETECT;
    _soundCore = SNDCORE_MAC;
    _videoCore = VIDCORE_SOFT;

    _prefs = [[NSUserDefaults standardUserDefaults] retain];

    /* Fill in all the settings. */
    if([_prefs objectForKey:@"BIOS Path"]) {
        [biosPath setStringValue:[_prefs stringForKey:@"BIOS Path"]];
    }
    else {
        [_prefs setObject:@"" forKey:@"BIOS Path"];
    }

    if([_prefs objectForKey:@"Emulate BIOS"]) {
        [emulateBios setState:[_prefs boolForKey:@"Emulate BIOS"] ?
            NSOnState : NSOffState];
    }
    else {
        [_prefs setBool:YES forKey:@"Emulate BIOS"];
    }

    if([_prefs objectForKey:@"MPEG ROM Path"]) {
        [mpegPath setStringValue:[_prefs objectForKey:@"MPEG ROM Path"]];
    }
    else {
        [_prefs setObject:@"" forKey:@"MPEG ROM Path"];
    }

    if([_prefs objectForKey:@"BRAM Path"]) {
        [bramPath setStringValue:[_prefs objectForKey:@"BRAM Path"]];
    }
    else {
        [_prefs setObject:@"" forKey:@"BRAM Path"];
    }

    if([_prefs objectForKey:@"Cartridge Path"]) {
        [cartPath setStringValue:[_prefs objectForKey:@"Cartridge Path"]];
    }
    else {
        [_prefs setObject:@"" forKey:@"Cartridge Path"];
    }

    if([_prefs objectForKey:@"Cartridge Type"]) {
        _cartType = [_prefs integerForKey:@"Cartridge Type"];

        if(_cartType != CART_NONE && _cartType != CART_DRAM8MBIT &&
           _cartType != CART_DRAM32MBIT) {
            [cartPath setEnabled:YES];
            [cartBrowse setEnabled:YES];
            [[cartPath cell] setPlaceholderString:@"Not Set"];
        }

        [cartType selectItemWithTag:_cartType];
    }
    else {
        [_prefs setInteger:CART_NONE forKey:@"Cartridge Type"];
    }

    if([_prefs objectForKey:@"Region"]) {
        _region = [_prefs integerForKey:@"Region"];
        [region selectItemWithTag:_region];
    }
    else {
        [_prefs setInteger:REGION_AUTODETECT forKey:@"Region"];
    }

    if([_prefs objectForKey:@"Sound Core"]) {
        _soundCore = [_prefs integerForKey:@"Sound Core"];
        [soundCore selectItemWithTag:_soundCore];
    }
    else {
        [_prefs setInteger:SNDCORE_MAC forKey:@"Sound Core"];
    }

    if([_prefs objectForKey:@"Video Core"]) {
        _videoCore = [_prefs integerForKey:@"Video Core"];
        [videoCore selectItemWithTag:_videoCore];
    }
    else {
        [_prefs setInteger:VIDCORE_OGL forKey:@"Video Core"];
    }

    [_prefs synchronize];
}

- (void)dealloc
{
    [_prefs release];
    [super dealloc];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    id obj = [notification object];

    if(obj == biosPath) {
        [_prefs setObject:[biosPath stringValue] forKey:@"BIOS Path"];
    }
    else if(obj == bramPath) {
        [_prefs setObject:[bramPath stringValue] forKey:@"BRAM Path"];
    }
    else if(obj == mpegPath) {
        [_prefs setObject:[mpegPath stringValue] forKey:@"MPEG ROM Path"];
    }
    else if(obj == cartPath) {
        [_prefs setObject:[cartPath stringValue] forKey:@"Cartridge Path"];
    }

    [_prefs synchronize];
}

- (IBAction)cartSelected:(id)sender
{
    _cartType = [[sender selectedItem] tag];

    switch(_cartType) {
        case CART_NONE:
        case CART_DRAM8MBIT:
        case CART_DRAM32MBIT:
            [cartPath setEnabled:NO];
            [cartPath setStringValue:@""];
            [cartBrowse setEnabled:NO];
            [[cartPath cell] setPlaceholderString:
             @"No file required for the selected cartridge"];
            break;

        default:
            [cartPath setEnabled:YES];
            [cartBrowse setEnabled:YES];
            [[cartPath cell] setPlaceholderString:@"Not Set"];
            break;
    }

    /* Update the preferences file. */
    [_prefs setObject:[cartPath stringValue] forKey:@"Cartridge Path"];
    [_prefs setInteger:_cartType forKey:@"Cartridge Type"];
    [_prefs synchronize];
}

- (IBAction)regionSelected:(id)sender
{
    _region = [[sender selectedItem] tag];

    /* Update the preferences file. */
    [_prefs setInteger:_region forKey:@"Region"];
    [_prefs synchronize];
}

- (IBAction)soundCoreSelected:(id)sender
{
    _soundCore = [[sender selectedItem] tag];

    /* Update the preferences file. */
    [_prefs setInteger:_soundCore forKey:@"Sound Core"];
    [_prefs synchronize];
}

- (IBAction)videoCoreSelected:(id)sender
{
    _videoCore = [[sender selectedItem] tag];

    /* Update the preferences file. */
    [_prefs setInteger:_videoCore forKey:@"Video Core"];
    [_prefs synchronize];
}

- (IBAction)biosBrowse:(id)sender
{
    NSOpenPanel *p = [NSOpenPanel openPanel];

    [p setTitle:@"Select a Saturn BIOS ROM"];

    if([p runModal] == NSFileHandlingPanelOKButton) {
        [biosPath setStringValue:[[[p URLs] objectAtIndex:0] path]];

        /* Update the preferences file. */
        [_prefs setObject:[biosPath stringValue] forKey:@"BIOS Path"];
        [_prefs synchronize];
    }
}

- (IBAction)mpegBrowse:(id)sender
{
    NSOpenPanel *p = [NSOpenPanel openPanel];

    [p setTitle:@"Select a MPEG ROM"];

    if([p runModal] == NSFileHandlingPanelOKButton) {
        [mpegPath setStringValue:[[[p URLs] objectAtIndex:0] path]];

        /* Update the preferences file. */
        [_prefs setObject:[mpegPath stringValue] forKey:@"MPEG ROM Path"];
        [_prefs synchronize];
    }
}

- (IBAction)bramBrowse:(id)sender
{
    NSOpenPanel *p = [NSOpenPanel openPanel];

    [p setTitle:@"Select a BRAM File"];

    if([p runModal] == NSFileHandlingPanelOKButton) {
        [bramPath setStringValue:[[[p URLs] objectAtIndex:0] path]];

        /* Update the preferences file. */
        [_prefs setObject:[bramPath stringValue] forKey:@"BRAM Path"];
        [_prefs synchronize];
    }
}

- (IBAction)cartBrowse:(id)sender
{
    NSOpenPanel *p = [NSOpenPanel openPanel];

    [p setTitle:@"Select the Cartridge File"];

    if([p runModal] == NSFileHandlingPanelOKButton) {
        [cartPath setStringValue:[[[p URLs] objectAtIndex:0] path]];

        /* Update the preferences file. */
        [_prefs setObject:[cartPath stringValue] forKey:@"Cartridge Path"];
        [_prefs synchronize];
    }
}

- (IBAction)biosToggle:(id)sender
{
    /* Update the preferences file. */
    [_prefs setBool:([sender state] == NSOnState) forKey:@"Emulate BIOS"];
    [_prefs synchronize];
}

- (IBAction)buttonSelect:(id)sender
{
    NSInteger rv;
    NSInteger tag = [sender tag];
    int port = tag > 12 ? 1 : 0;
    u8 num = tag > 12 ? tag - 13 : tag;
    u32 value = PERCocoaGetKey(num, port);
    unichar ch;

    /* Fill in current setting from prefs */
    if(value != (u32)-1) {
        switch(value) {
            case '\r':
                ch = 0x23CE;
                break;

            case '\t':
                ch = 0x21E5;
                break;

            case 27:
                ch = 0x241B;
                break;

            case 127:
                ch = 0x232B;
                break;

            case NSLeftArrowFunctionKey:
                ch = 0x2190;
                break;

            case NSUpArrowFunctionKey:
                ch = 0x2191;
                break;

            case NSRightArrowFunctionKey:
                ch = 0x2192;
                break;

            case NSDownArrowFunctionKey:
                ch = 0x2193;
                break;

            default:
                ch = toupper(((int)value));
        }

        [buttonBox setStringValue:[NSString stringWithCharacters:&ch length:1]];
    }
    else {
        [buttonBox setStringValue:@""];
    }

    /* Open up the sheet and ask for the user's input */
    [NSApp beginSheet:buttonAssignment
       modalForWindow:prefsPane
        modalDelegate:self
       didEndSelector:nil
          contextInfo:NULL];

    rv = [NSApp runModalForWindow:buttonAssignment];
    [NSApp endSheet:buttonAssignment];
    [buttonAssignment orderOut:nil];

    /* Did the user accept what they put in? */
    if(rv == NSOKButton) {
        NSString *s = [buttonBox stringValue];
        u32 val;

        /* This shouldn't happen... */
        if([s length] < 1) {
            return;
        }

        switch([s characterAtIndex:0]) {
            case 0x23CE:    /* Return */
                val = '\r';
                break;

            case 0x21E5:    /* Tab */
                val = '\t';
                break;

            case 0x241B:    /* Escape */
                val = 27;
                break;

            case 0x232B:    /* Backspace */
                val = 127;
                break;

            case 0x2190:    /* Left */
                val = NSLeftArrowFunctionKey;
                break;

            case 0x2191:    /* Up */
                val = NSUpArrowFunctionKey;
                break;

            case 0x2192:    /* Right */
                val = NSRightArrowFunctionKey;
                break;

            case 0x2193:    /* Down */
                val = NSDownArrowFunctionKey;
                break;

            default:
                val = tolower([s characterAtIndex:0]);
        }

        /* Update the key mapping, if we're already running. This will also save
           the key to the preferences. */
        if(tag > 12) {
            PERCocoaSetKey(val, tag - 13, 1);
        }
        else {
            PERCocoaSetKey(val, tag, 0);
        }
    }
}

- (IBAction)buttonSetOk:(id)sender
{
    [NSApp stopModalWithCode:NSOKButton];
}

- (IBAction)buttonSetCancel:(id)sender
{
    [NSApp stopModalWithCode:NSCancelButton];
}

- (int)cartType
{
    return _cartType;
}

- (int)region
{
    return _region;
}

- (int)soundCore
{
    return _soundCore;
}

- (int)videoCore
{
    return _videoCore;
}

- (NSString *)biosPath
{
    return [biosPath stringValue];
}

- (BOOL)emulateBios
{
    return [emulateBios state] == NSOnState;
}

- (NSString *)mpegPath
{
    return [mpegPath stringValue];
}

- (NSString *)bramPath
{
    return [bramPath stringValue];
}

- (NSString *)cartPath
{
    return [cartPath stringValue];
}

@end /* @implementation YabausePrefsController */
