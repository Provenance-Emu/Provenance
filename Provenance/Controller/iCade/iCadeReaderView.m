/*
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

#import "iCadeReaderView.h"
#import <UIKit/UIKit.h>

static const char *ON_STATES_EN  = "wdxayhujikol[1";
static const char *OFF_STATES_EN = "eczqtrfnmpgv]2";

#if TARGET_OS_TV
static const char *ON_STATES_FR  = "zdxqyhujikol";
static const char *OFF_STATES_FR = "ecwatrfn,pgv";

static const char *ON_STATES_DE  = "wdxazhujikol";
static const char *OFF_STATES_DE = "ecyqtrfnmpgv";
#endif

@interface iCadeReaderView() <UIKeyInput>

- (void)willResignActive;
- (void)didBecomeActive;

@property (nonatomic, assign) const char *onStates;
@property (nonatomic, assign) const char *offStates;

@end

@implementation iCadeReaderView

@synthesize iCadeState=_iCadeState, delegate=_delegate, active;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    inputView = [[UIView alloc] initWithFrame:CGRectZero];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];

    [self applyKeyMappingForCurrentLocale];

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)willResignActive {
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
    if (active == value) {
        if (value) {
            [self resignFirstResponder];
        } else {
            return;
        }
    }
    
    active = value;
    if (active) {
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
            [self becomeFirstResponder];
        }
    } else {
        [self resignFirstResponder];
    }
}

- (UIView*) inputView {
    return inputView;
}

- (void)setDelegate:(id<iCadeEventDelegate>)delegate {
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
    // does not to work on tvOS, use keyCommands + keyPressed instead
}

- (void)deleteBackward {
    // This space intentionally left blank to complete protocol
}

#pragma mark - keys

- (void)applyKeyMappingForCurrentLocale {
#if TARGET_OS_TV
    NSString *localeIdentifier = [[NSLocale currentLocale] localeIdentifier];
    if ([localeIdentifier hasPrefix:@"de"]) {
        self.onStates = ON_STATES_DE;
        self.offStates = OFF_STATES_DE;
    } else if ([localeIdentifier hasPrefix:@"fr"]) {
        self.onStates = ON_STATES_FR;
        self.offStates = OFF_STATES_FR;
    } else {
        self.onStates = ON_STATES_EN;
        self.offStates = OFF_STATES_EN;
    }
#else
    self.onStates = ON_STATES_EN;
    self.offStates = OFF_STATES_EN;
#endif
}

- (NSArray * )keyCommands {
    NSMutableArray *keys = [NSMutableArray array];
    
    int numberOfStates = (int)(strlen(_onStates)+strlen(_offStates));
    char states[numberOfStates+1]; //+1 for crash on release
    strcpy(states,_onStates);
    strcat(states,_offStates);
    
    for (int i=0; i<numberOfStates; i++) {
        UIKeyCommand *keyCommand = [UIKeyCommand keyCommandWithInput: [NSString stringWithFormat:@"%c" , states[i]] modifierFlags: 0 action: @selector(keyPressed:)];
        [keys addObject:keyCommand];
    }
    
    return keys;
}

- (void)keyPressed:(UIKeyCommand *)keyCommand {
    char ch = [keyCommand.input characterAtIndex:0];
    char *p = strchr(_onStates, ch);
    bool stateChanged = false;
    if (p) {
        long index = p-_onStates;
        _iCadeState |= (1 << index);
        stateChanged = true;
        if (_delegateFlags.buttonDown) {
            [_delegate buttonDown:(1 << index)];
        }
    } else {
        p = strchr(_offStates, ch);
        if (p) {
            long index = p-_offStates;
            _iCadeState &= ~(1 << index);
            stateChanged = true;
            if (_delegateFlags.buttonUp) {
                [_delegate buttonUp:(1 << index)];
            }
        }
    }
    
    if (stateChanged && _delegateFlags.stateChanged) {
        [_delegate stateChanged:_iCadeState];
    }
    
    static int cycleResponder = 0;
    if (++cycleResponder > 20) {
        // necessary to clear a buffer that accumulates internally
        cycleResponder = 0;
        [self resignFirstResponder];
        [self becomeFirstResponder];
    }
}

@end
