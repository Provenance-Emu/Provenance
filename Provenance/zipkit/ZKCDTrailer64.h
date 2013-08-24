//
//  ZKCDTrailer64.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>

@interface ZKCDTrailer64 : NSObject {
@private
	NSUInteger magicNumber;
	unsigned long long sizeOfTrailer;
	NSUInteger versionMadeBy;
	NSUInteger versionNeededToExtract;
	NSUInteger thisDiskNumber;
	NSUInteger diskNumberWithStartOfCentralDirectory;
	unsigned long long numberOfCentralDirectoryEntriesOnThisDisk;
	unsigned long long totalNumberOfCentralDirectoryEntries;
	unsigned long long sizeOfCentralDirectory;
	unsigned long long offsetOfStartOfCentralDirectory;
}

+ (ZKCDTrailer64 *) recordWithData:(NSData *)data atOffset:(NSUInteger)offset;
+ (ZKCDTrailer64 *) recordWithArchivePath:(NSString *)path atOffset:(unsigned long long)offset;

- (NSData *) data;
- (NSUInteger) length;

@property (assign) NSUInteger magicNumber;
@property (assign) unsigned long long sizeOfTrailer;
@property (assign) NSUInteger versionMadeBy;
@property (assign) NSUInteger versionNeededToExtract;
@property (assign) NSUInteger thisDiskNumber;
@property (assign) NSUInteger diskNumberWithStartOfCentralDirectory;
@property (assign) unsigned long long numberOfCentralDirectoryEntriesOnThisDisk;
@property (assign) unsigned long long totalNumberOfCentralDirectoryEntries;
@property (assign) unsigned long long sizeOfCentralDirectory;
@property (assign) unsigned long long offsetOfStartOfCentralDirectory;

@end