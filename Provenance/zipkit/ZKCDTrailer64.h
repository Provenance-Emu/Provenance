//
//  ZKCDTrailer64.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>

@interface ZKCDTrailer64 : NSObject

+ (ZKCDTrailer64 *) recordWithData:(NSData *)data atOffset:(UInt64)offset;
+ (ZKCDTrailer64 *) recordWithArchivePath:(NSString *)path atOffset:(UInt64)offset;

- (NSData *)	data;
- (NSUInteger)	length;

@property (assign) UInt32 magicNumber;
@property (assign) unsigned long long sizeOfTrailer;
@property (assign) UInt32 versionMadeBy;
@property (assign) UInt32 versionNeededToExtract;
@property (assign) UInt32 thisDiskNumber;
@property (assign) UInt32 diskNumberWithStartOfCentralDirectory;
@property (assign) UInt64 numberOfCentralDirectoryEntriesOnThisDisk;
@property (assign) UInt64 totalNumberOfCentralDirectoryEntries;
@property (assign) UInt64 sizeOfCentralDirectory;
@property (assign) UInt64 offsetOfStartOfCentralDirectory;

@end