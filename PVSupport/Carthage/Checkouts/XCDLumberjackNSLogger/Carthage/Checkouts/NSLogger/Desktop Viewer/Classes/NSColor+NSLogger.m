//
//  NSColor+NSLogger.m
//  NSLogger
//
//  Created by Julián Romero on 1/17/13.
//  Copyright (c) 2013 Julián Romero. All rights reserved.
//

#import "NSColor+NSLogger.h"

@implementation NSColor (NSLogger)

- (BOOL)_setBold:(NSInteger)bold {
    static BOOL _bold = NO;
    if (bold >= 0) {
        _bold = bold;
    }
    return _bold;
}

- (void)setBold:(BOOL)bold {
    [self _setBold:bold];
}

- (BOOL)isBold {
    return [self _setBold:-1];
}

@end
