//
//  PVLogEntry.h
//  PVSupport
//
//  Created by Mattiello, Joseph R on 1/27/14.
//  Copyright (c) 2014 Joe Mattiello. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSDate *__PVLoggingStartupTime;

#import <Foundation/Foundation.h>
typedef NS_OPTIONS(NSInteger, PVLogLevel) {
    PVLogLevelUndefined = 0,
    PVLogLevelError = 0x0001,
    PVLogLevelWarn = 0x0001 << 2,
    PVLogLevelInfo = 0x0001 << 3,
    PVLogLevelDebug = 0x0001 << 4,
    PVLogLevelFile = 0x0001 << 5
};

@interface PVLogEntry : NSObject {
@public
        // Logging imprance level. Defaults to PVLogLevelUndefined.
    PVLogLevel          level;

        // The text message of the log entry
    NSString *          text;

    /**
     *  Optional, not all entries need this
     */
        // Class of instance that created the log entry
    NSString *          classString;
        // Function string of location of log entry
    NSString *          functionString;
        // Line numer in file that entry was made
    NSString *          lineNumberString;

@private

    /**
     *  Auto-generated
     */

        // Time of entry creation
    NSDate *            time;

        // Unique int int key for entry
    NSUInteger          entryIndex;

        // Time since known start of app Here for convenience/performance,
        // spread the calculation out.
    NSTimeInterval      offset;
}

    // HTML color formatted string
-(NSString*)htmlString;
    // String for printing w/o location in file and line
- (NSString*)string;
    // String for printing with file and line info
- (NSString*)stringWithLocation;

@end
