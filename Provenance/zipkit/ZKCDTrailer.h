//
//  ZKCDTrailer.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>

@interface ZKCDTrailer : NSObject {
@private
	NSUInteger magicNumber;
	NSUInteger thisDiskNumber;
	NSUInteger diskNumberWithStartOfCentralDirectory;
	NSUInteger numberOfCentralDirectoryEntriesOnThisDisk;
	NSUInteger totalNumberOfCentralDirectoryEntries;
	unsigned long long sizeOfCentralDirectory;
	unsigned long long offsetOfStartOfCentralDirectory;
	NSUInteger commentLength;
	NSString *comment;
}

+ (ZKCDTrailer *) recordWithData:(NSData *)data atOffset:(NSUInteger) offset;
+ (ZKCDTrailer *) recordWithData:(NSData *)data;
+ (ZKCDTrailer *) recordWithArchivePath:(NSString *) path;
- (NSData *) data;
- (NSUInteger) length;
- (BOOL) useZip64Extensions;

@property (assign) NSUInteger magicNumber;
@property (assign) NSUInteger thisDiskNumber;
@property (assign) NSUInteger diskNumberWithStartOfCentralDirectory;
@property (assign) NSUInteger numberOfCentralDirectoryEntriesOnThisDisk;
@property (assign) NSUInteger totalNumberOfCentralDirectoryEntries;
@property (assign) unsigned long long sizeOfCentralDirectory;
@property (assign) unsigned long long offsetOfStartOfCentralDirectory;
@property (assign) NSUInteger commentLength;
@property (copy) NSString *comment;

@end