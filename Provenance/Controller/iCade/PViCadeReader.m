//
//  PViCadeReader.m
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#import "PViCadeReader.h"
#import "iCadeReaderView.h"

static PViCadeReader* sharedReader = nil;

@implementation PViCadeReader

+(PViCadeReader*) sharedReader {
    if (!sharedReader) {
        sharedReader = [[PViCadeReader alloc] init];
    }
    
    return sharedReader;
}

-(instancetype) init {
    if (self = [super init]) {
        _internalReader = [[iCadeReaderView alloc] initWithFrame:CGRectZero];
    }
    return self;
}

-(void) listenToWindow:(UIWindow *)window {
    UIWindow* keyWindow = window?:[UIApplication sharedApplication].keyWindow;
    if (keyWindow != _internalReader.window) {
        [_internalReader removeFromSuperview];
        [keyWindow addSubview:_internalReader];
    }
    else {
        [keyWindow bringSubviewToFront:_internalReader];
    }
    
    _internalReader.delegate = self;
    _internalReader.active = YES;
}

-(void) listenToKeyWindow {
    [self listenToWindow:nil];
}

-(void) stopListening {
    _internalReader.active = NO;
    _internalReader.delegate = nil;
    [_internalReader removeFromSuperview];
}

-(iCadeState) state {
    return _internalReader.iCadeState;
}

#pragma mark - iCadeEventDelegate

- (void)buttonDown:(iCadeState)button {
    if (self.buttonDown) {
        self.buttonDown(button);
    }
}

- (void)buttonUp:(iCadeState)button {
    if (self.buttonUp) {
        self.buttonUp(button);
    }
}

@end
