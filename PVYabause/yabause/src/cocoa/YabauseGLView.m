/*  Copyright 2010, 2014 Lawrence Sebald

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

#include "YabauseGLView.h"

#include "peripheral.h"
#include "vdp1.h"

@interface YabauseGLView (InternalFunctions)
/* These are nice to have, but not really necessary to things... */
- (float)width;
- (float)height;
@end

@implementation YabauseGLView

- (id)initWithFrame:(NSRect)frameRect
{
    NSOpenGLPixelFormatAttribute attrs[] = {
        NSOpenGLPFAWindow,
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFADepthSize, 32,
        NSOpenGLPFADoubleBuffer,
        0
    };

    NSOpenGLPixelFormat *fmt;

    fmt = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];

    if(fmt == nil)  {
        [fmt release];
        return nil;
    }

    if(!(self = [super initWithFrame:frameRect pixelFormat:fmt])) {
        [fmt release];
        return nil;
    }

    _isFullscreen = NO;

    [fmt release];

    return self;
}

- (void)toggleFullscreen
{
    CGError err;
    CGDisplayFadeReservationToken token;

    err = CGAcquireDisplayFadeReservation(kCGMaxDisplayReservationInterval,
                                          &token);

    if(err == kCGErrorSuccess) {
        CGDisplayFade(token, 0.5, kCGDisplayBlendNormal,
                      kCGDisplayBlendSolidColor, 0, 0, 0, 1);
    }

    if(!_isFullscreen) {
        NSScreen *s = [NSScreen mainScreen];
        NSRect dispRect = [s frame];

        fsWindow = [[NSWindow alloc] initWithContentRect:dispRect
                                               styleMask:NSBorderlessWindowMask
                                                 backing:NSBackingStoreBuffered
                                                   defer:YES];

        [fsWindow setLevel:NSMainMenuWindowLevel + 1];
        [fsWindow setOpaque:YES];
        [fsWindow setHidesOnDeactivate:YES];

        oldFrame = [self frame];
        dispRect.origin.x = dispRect.origin.y = 0;
        [self setFrame:dispRect];
        [fsWindow setContentView:self];
        [fsWindow makeKeyAndOrderFront:self];
    }
    else {
        [self setFrame:oldFrame];
        [window setContentView:self];
        [fsWindow release];
        fsWindow = nil;
    }

    if(err == kCGErrorSuccess)  {
        CGDisplayFade(token, 0.5, kCGDisplayBlendNormal,
                      kCGDisplayBlendSolidColor, 0, 0, 0, 0);
        CGReleaseDisplayFadeReservation(token);
    }

    if(VIDCore)
        VIDCore->Resize([self width], [self height], !_isFullscreen);

    _isFullscreen = !_isFullscreen;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)keyDown:(NSEvent *)event
{
    if([[event charactersIgnoringModifiers] length] >= 1) {
        PerKeyDown([[event charactersIgnoringModifiers] characterAtIndex:0]);
    }
}

- (void)keyUp:(NSEvent *)event
{
    if([[event charactersIgnoringModifiers] length] >= 1) {
        PerKeyUp([[event charactersIgnoringModifiers] characterAtIndex:0]);
    }
}

- (void)showWindow
{
    [window makeKeyAndOrderFront:self];
}

- (void)reshape
{
    CGLContextObj cxt = CGLGetCurrentContext();

    /* Make sure that the emulation thread doesn't attempt to do any OpenGL
       calls during the resize event, otherwise one of the two will crash. */
    CGLLockContext(cxt);

    if(VIDCore)
        VIDCore->Resize([self width], [self height], !!_isFullscreen);

    CGLUnlockContext(cxt);

    [super reshape];
}

- (void)drawRect:(NSRect)rect
{
    CGLContextObj cxt = CGLGetCurrentContext();

    /* Make sure that the emulation thread doesn't attempt to do any OpenGL
       calls during the flush to the screen. */
    CGLLockContext(cxt);
    [[self openGLContext] flushBuffer];
    CGLUnlockContext(cxt);
}

@end /* @implementation YabauseGLView */

@implementation YabauseGLView (InternalFunctions)

- (float)width
{
    return [self bounds].size.width;
}

- (float)height
{
    return [self bounds].size.height;
}

@end /* @implementation YabauseGLView (InternalFunctions) */
