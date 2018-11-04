/*  Copyright 2010, 2012 Lawrence Sebald

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

#ifndef YabauseController_h
#define YabauseController_h

#import <Cocoa/Cocoa.h>

@class YabauseGLView;
@class YabausePrefsController;

@interface YabauseController : NSObject {
    IBOutlet YabauseGLView *view;
    IBOutlet NSPanel *prefsPane;
    IBOutlet YabausePrefsController *prefs;
    IBOutlet NSMenuItem *frameskip;
    IBOutlet NSWindow *logWindow;
    IBOutlet NSTextView *logView;
    BOOL _running;
    BOOL _paused;
    NSLock *_runLock;
    NSThread *_emuThd;
    char *_bramFile;
    char *_isoFile;
    BOOL _doneExecuting;
}

- (void)awakeFromNib;
- (void)dealloc;

/* NSWindow delegate methods */
- (BOOL)windowShouldClose:(id)sender;

/* NSApplication delegate methods */
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app;

- (IBAction)showPreferences:(id)sender;
- (IBAction)runBIOS:(id)sender;
- (IBAction)runCD:(id)sender;
- (IBAction)runISO:(id)sender;
- (IBAction)toggleFullscreen:(id)sender;
- (IBAction)toggle:(id)sender;
- (IBAction)toggleFrameskip:(id)sender;
- (IBAction)pause:(id)sender;
- (IBAction)reset:(id)sender;

- (YabauseGLView *)view;

@end

extern YabauseController *controller;

#endif /* !YabauseController_h */
