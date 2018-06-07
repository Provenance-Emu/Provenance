//
//  PVProvenanceLogging.m
//  PVSupport
//
//  Created by Mattiello, Joseph R on 1/27/14.
//  Copyright (c) 2014 Joe Mattiello. All rights reserved.
//

#import "PVProvenanceLogging.h"
#import "PVLogEntry.h"

@implementation PVProvenanceLogging  {
@private
    NSMutableArray *_history;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self validateLogDirectoryExists];
        [self deleteOldLogs];
    }
    return self;
}

#pragma mark - PVLogging overwrites


- (NSString *) directoryForLogs {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES); // cache area (not backed up)
    NSString *logPath = [paths[0] stringByAppendingPathComponent:@"/Logs"];
    return logPath;
}

- (NSArray*)logFilePaths {
        //add attachments
    NSString *docsDirectory = [self directoryForLogs];
    NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docsDirectory error:nil];
    NSArray *onlyLogs = [dirContents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self BEGINSWITH 'hnlog'"]];
    return onlyLogs;
}

- (NSArray*)logFileInfos {
        // TODO
    return nil;
}

- (void)flushLogs {
        // NOthing to do here since we close the file log every write

        // TODO :: keep the file open and call flush on app close
}

- (void) logToFile: (NSString*) inString, ... {

	va_list args;
	va_start(args, inString);
	NSString *expString = [[NSString alloc] initWithFormat:inString arguments:args];
	va_end(args);

        // DSwift - inject timestamp
    static NSDateFormatter *format = nil;
    if (! format) {
        format = [[NSDateFormatter alloc] init];
            //[format setDateFormat:@"yyyy'-'MM'-'dd"];
        [format setDateStyle:NSDateFormatterMediumStyle];
        [format setTimeStyle:NSDateFormatterMediumStyle];
    }
    NSString *timestamp = [format stringFromDate:[NSDate date]];
    NSString *finalString = [[NSString alloc] initWithFormat:@"%@ %@\r\n", timestamp, expString];

	NSData *dataToWrite = [finalString dataUsingEncoding:NSUTF8StringEncoding];

	NSString *docsDirectory = [self directoryForLogs];
	NSString *path = [docsDirectory stringByAppendingPathComponent:[self logFilename]];

	if (![[NSFileManager defaultManager] isWritableFileAtPath: path]) {
		[[NSFileManager defaultManager] createFileAtPath: path
												contents: [@"PVLOGGING STARTED\r\n" dataUsingEncoding: NSUTF8StringEncoding]
											  attributes: nil];
	}

	NSFileHandle* bmlogFile = [NSFileHandle fileHandleForWritingAtPath:path];
	[bmlogFile seekToEndOfFile];

        // Write the file
	[bmlogFile writeData: dataToWrite];

        // This is ineffecient, seeking and closing every write is slow. Keep
        // open, call close on app shutdown instead
    [bmlogFile closeFile];
}

#pragma mark - Internal
- (NSString *) logFilename {
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"yyyy'-'MM'-'dd"];
    NSString *dateString = [format stringFromDate:[NSDate date]];
    return [[NSString alloc] initWithFormat:@"hnlog_%@.txt",dateString];
}

-(BOOL) shouldDeleteFileWithName:(NSString *)name {

    NSDateFormatter *format = [[NSDateFormatter alloc] init]; // DSwift - adding autorelease - this was leaking.
    [format setDateFormat:@"yyyy'-'MM'-'dd"];

    for(int i=0;i<7;i++){
        NSDate *day = [[NSDate date] dateByAddingTimeInterval:-60*60*24*i];
        NSString *dateString = [format stringFromDate:day];
        NSString *logname = [[NSString alloc] initWithFormat:@"hnlog_%@.txt",dateString];
        if([logname isEqualToString:name]){
            return NO;
        }
    }

    return YES;
}

-(void) validateLogDirectoryExists {
	NSString *logPath = [self directoryForLogs];

        // check for existence of cache directory.
	if ([[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
		return;
	}

        // if we get here, there is no cache directory so make one...
	NSError* error = nil;
        // create a new cache directory
	BOOL result = [[NSFileManager defaultManager] createDirectoryAtPath:logPath
											withIntermediateDirectories:YES
															 attributes:nil
																  error:&error];
	if (!result) {
		[NSException raise:@"PVCachePluginFileError" format:@"Unable to create cache directory.  %@", error];
	}
}

- (void)addHistoryEvent:(NSObject*) event {

        // check if the FIFO stack is over quota
        // save the history event
    if (_history.count >= stackSize) {
        [_history removeLastObject];
    }

        // If incoming event isn't of PVLogEntry type then convert the object
        // to a string and create an otherwise empty entry
    if ( ![event isKindOfClass:[PVLogEntry class]] ) {

        PVLogEntry *newEntry = [PVLogEntry new];

            // NSStrings directly convert
        if ( [event isKindOfClass:[NSString class]] ) {
            newEntry->text = (NSString*)event;
        } else {
                // All other types need a string conversion
            newEntry->text = [event description];
        }

        event = newEntry;
    }

    [_history insertObject:event
                   atIndex:0];
    
    [[PVLogging sharedInstance] notifyListeners];
}

-(void)deleteOldLogs {
    NSArray *logFiles = [self logFilePaths];
    NSFileManager *fm = [NSFileManager defaultManager];

    for (NSString *path in logFiles) {
        NSError *error;

        BOOL success =
        [fm removeItemAtPath:path
                       error:&error];
        if (!success) {
            ELOG(@"%@", error);
        }
    }
}

@end

