/*
 Copyright (C) 2012,2013 by Rand Paulin for Black Powder Media, iMpulse Controller
 
 Copyright (C) 2011 by Stuart Carnie
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "iMpulseReaderView.h"

/* 1st player
 UP ON,OFF  = w,e
 RT ON,OFF  = d,c
 DN ON,OFF  = x,z
 LT ON,OFF  = a,q
 V  ON,OFF  = y,t   iMpulse at  3 o'clock position, Generic A
 u  ON,OFF  = h,r   iMpulse Left Shoulder,          Generic B
    ON,OFF  = u,f   (see 2nd player mode RT),       Generic C
 n  ON,OFF  = j,n   iMpulse Right Shoulder,         Generic D
    ON,OFF  = i,m   (see 2nd player mode DN),       Generic E
 W  ON,OFF  = k,p   iMpulse at  6 o'clock position, Generic F
 M  ON,OFF  = o,g   iMpulse at 12 o'clock position, Generic G
 A  ON,OFF  = l,v   iMpulse at  9 o'clock position, Generic H
 */

/* 2nd player
 UP ON,OFF  = [,]
/RT ON,OFF  = i,m   (Generic E)
 DN ON,OFF  = s,b
/LT ON,OFF  = u,f   (Generic C)
 V  ON,OFF  = 3,4   V on iMpulse at  3 o'clock position
 W  ON,OFF  = 1,2   W on iMpulse at  6 o'clock position
 M  ON,OFF  = 7,8   M on iMpulse at 12 o'clock position
 A  ON,OFF  = 5,6   A on iMpulse at  9 o'clock position
 u  ON,OFF  = 9,0   iMpulse Left Shoulder
 n  ON,OFF  = -,=   iMpulse Right Shoulder
 */

static const char *ON_STATES  = "wdxayhujikol[s31759-";
static const char *OFF_STATES = "eczqtrfnmpgv]b42860=";

@interface iMpulseReaderView()

- (void)didEnterBackground;
- (void)didBecomeActive;

@end

@implementation iMpulseReaderView

@synthesize iMpulseState=_iMpulseState, delegate=_delegate, active;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    inputView = [[UIView alloc] initWithFrame:CGRectZero];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)didEnterBackground {
    if (self.active)
        [self resignFirstResponder];
}

- (void)didBecomeActive {
    if (self.active)
        [self becomeFirstResponder];
}

- (BOOL)canBecomeFirstResponder { 
    return YES; 
}

- (void)setActive:(BOOL)value {
    if (active == value) return;
    
    active = value;
    if (active) {
        [self becomeFirstResponder];
    } else {
        [self resignFirstResponder];
    }
}

- (UIView*) inputView {
    return inputView;
}

- (void)setDelegate:(id<iMpulseEventDelegate>)delegate {
    _delegate = delegate;
    if (!_delegate) return;
    
    _delegateFlags.stateChanged = [_delegate respondsToSelector:@selector(stateChanged:)];
    _delegateFlags.buttonDown = [_delegate respondsToSelector:@selector(buttonDown:)];
    _delegateFlags.buttonUp = [_delegate respondsToSelector:@selector(buttonUp:)];
}

#pragma mark -
#pragma mark UIKeyInput Protocol Methods

- (BOOL)hasText {
    return NO;
}

- (void)insertText:(NSString *)text {
    
    char ch = [text characterAtIndex:0];
    char *p = strchr(ON_STATES, ch);
    bool stateChanged = false;
    if (p) {
        int index = p-ON_STATES;
        _iMpulseState |= (1 << index);
        stateChanged = true;
        if (_delegateFlags.buttonDown) {
            [_delegate buttonDown:(1 << index)];
        }
    } else {
        p = strchr(OFF_STATES, ch);
        if (p) {
            int index = p-OFF_STATES;
            _iMpulseState &= ~(1 << index);
            stateChanged = true;
            if (_delegateFlags.buttonUp) {
                [_delegate buttonUp:(1 << index)];
            }
        }
    }

    if (stateChanged && _delegateFlags.stateChanged) {
        [_delegate stateChanged:_iMpulseState];
    }
    
    static int cycleResponder = 0;
    if (++cycleResponder > 20) {
        // necessary to clear a buffer that accumulates internally
        cycleResponder = 0;
        [self resignFirstResponder];
        [self becomeFirstResponder];
    }
}

- (void)deleteBackward {
    // This space intentionally left blank to complete protocol
}

@end
