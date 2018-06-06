//
//  PVLogEntry.m
//  PVSupport
//
//  Created by Mattiello, Joseph R on 1/27/14.
//  Copyright (c) 2014 Joe Mattiello. All rights reserved.
//

#import "PVLogEntry.h"
#import "PVLogging.h"

NSUInteger __PVLogEntryIndexCounter = 0;
    // Time of initialization.
    // Used to calculate offsets
NSDate *__PVLoggingStartupTime;

const char * const levelStrings[] = {
    "U",
    "**Error**",
    "*WARN*",
    "I",
    "D"
};

@implementation PVLogEntry

- (instancetype)init
{
    self = [super init];
    if (self) {
        self->time = [NSDate date];
        self->entryIndex = ++__PVLogEntryIndexCounter;
        self->offset = [__PVLoggingStartupTime timeIntervalSinceNow]*(-1);
    }
    return self;
}

-(NSString*)description{
    return [NSString stringWithFormat:@"%4.2f [%@:%@:%s] %@",offset, functionString, lineNumberString, levelStrings[level], text];
}

- (NSString*)string {
    return [NSString stringWithFormat:@"%4.2f [%s] %@",offset, levelStrings[level], text];
}

- (NSString*)stringWithLocation {
    return [self description];
}

    // TODO :: Make a PVLog HTML formatter
-(NSString*)htmlString{
    static BOOL toggle = YES;

        // Colors in theme, ligest to darkest
    char *color1 = "#ECE9F9";
    char *color2 = "#D4D1E0";
    char *color3 = "#B0ADB9";
    char *color4 = "#414045";
    char *color5 = "#37363A";


        // The complimentaries of the first
    char *compColor1 = "#F9F7E9";
    char *compColor2 = "#FFFFFF";

    char *timeColor = color1;
    char *functionColor = color3;
    char *lineNumberColor = color2;

    char *textColor = toggle ? compColor2 : compColor1;

        //Toggle background color for each line
    char *backgroundColor = toggle ? color4 : color5;
    BOOL_TOGGLE(toggle);

    return [NSString stringWithFormat:@" \
            <span style=\"background-color: %s;\"> \
            <span id='time' style=\"color:%s\">%4.2f</span> \
            <span id='function' style=\"color:%s\">%@</span> \
            <span style=\"color:%s\">%@</span> \
            <span style=\"color:%s\">%@</span> \
            </span>",backgroundColor,
            timeColor, offset,
            functionColor, functionString,
            lineNumberColor, lineNumberString,
            textColor, text];
}

@end
