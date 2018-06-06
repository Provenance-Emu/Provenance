//
//  PVProvenanceLogging.h
//  PVSupport
//
//  Created by Mattiello, Joseph R on 1/27/14.
//  Copyright (c) 2014 Joe Mattiello. All rights reserved.
//

#import <PVSupport/PVLogging.h>

#define PVLogEntryMake(loglevel, format, ...) \
{ \
PVLogEntry *entry = [PVLogEntry new]; \
entry->lineNumberString = [NSString stringWithFormat:@"%d",__LINE__]; \
entry->classString = [[self class] description]; \
entry->functionString = [NSString stringWithCString:__PRETTY_FUNCTION__ encoding:NSASCIIStringEncoding]; \
entry->text = [NSString stringWithFormat:(format), ##__VA_ARGS__]; \
entry->level = loglevel; \
[[PVLogging sharedInstance] addHistoryEvent:entry]; \
ToConsole(entry); \
}

@interface PVProvenanceLogging : NSObject <PVLoggingEntity>

/**
 Determine if this file needs to be deleted
 */
-(BOOL) shouldDeleteFileWithName:(NSString *)name;

    // Can add anything, will print using description if not a string or LogEntry
- (void)addHistoryEvent:(NSObject *)event;

- (void) logToFile: (NSString*) inString, ... ;

@end
