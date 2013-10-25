//
//  ZKCDTrailer.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>

@interface ZKCDTrailer : NSObject

+ (ZKCDTrailer *) recordWithData:(NSData *)data atOffset:(UInt64)offset;
+ (ZKCDTrailer *) recordWithData:(NSData *)data;
+ (ZKCDTrailer *) recordWithArchivePath:(NSString *)path;
- (NSData *)            data;
- (NSUInteger)          length;
- (BOOL)                useZip64Extensions;

@property (assign) UInt32 magicNumber;
@property (assign) UInt32 thisDiskNumber;
@property (assign) UInt32 diskNumberWithStartOfCentralDirectory;
@property (assign) UInt32 numberOfCentralDirectoryEntriesOnThisDisk;
@property (assign) UInt32 totalNumberOfCentralDirectoryEntries;
@property (assign) UInt64 sizeOfCentralDirectory;
@property (assign) UInt64 offsetOfStartOfCentralDirectory;
@property (assign) UInt32 commentLength;
@property (copy) NSString *comment;

@end