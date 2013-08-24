//
//  ZKLog.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>

enum ZKLogLevel {
	ZKLogLevelNotice = 3,
	ZKLogLevelError = 2,
	ZKLogLevelDebug = 1,
	ZKLogLevelAll = 0,
};

#define ZKLog(s, l, ...) [[ZKLog sharedInstance] logFile:__FILE__ lineNumber:__LINE__ level:l format:(s), ## __VA_ARGS__]

#define ZKLogError(s, ...) ZKLog((s), ZKLogLevelError, ## __VA_ARGS__)
#define ZKLogNotice(s, ...) ZKLog((s), ZKLogLevelNotice, ## __VA_ARGS__)
#define ZKLogDebug(s, ...) ZKLog((s), ZKLogLevelDebug, ## __VA_ARGS__)

#define ZKLogWithException(e) ZKLogError(@"Exception in %@: \n\tname: %@\n\treason: %@\n\tuserInfo: %@", NSStringFromSelector(_cmd), [e name], [e reason], [e userInfo]);
#define ZKLogWithError(e) ZKLogError(@"Error in %@: \n\tdomain: %@\n\tcode: %@\n\tdescription: %@", NSStringFromSelector(_cmd), [e domain], [e code], [e localizedDescription]);

#define ZKStringFromBOOL(b) (b ? @"YES": @"NO")

extern NSString* const ZKLogLevelKey;
extern NSString* const ZKLogToFileKey;

@interface ZKLog : NSObject {
@private
	NSUInteger minimumLevel;
	NSDateFormatter *dateFormatter;
	int pid;
	NSString *logFilePath;
	FILE *logFilePointer;
}

- (void) logFile:(char*) sourceFile lineNumber:(NSUInteger) lineNumber level:(NSUInteger) level format:(NSString*) format, ...;

- (NSString *) levelToLabel:(NSUInteger) level;

+ (ZKLog *) sharedInstance;

@property (assign) NSUInteger minimumLevel;
@property (retain) NSDateFormatter *dateFormatter;
@property (assign) int pid;
@property (copy) NSString *logFilePath;
@property (assign) FILE *logFilePointer;

@end