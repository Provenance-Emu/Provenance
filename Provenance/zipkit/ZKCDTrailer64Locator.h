//
//  ZKCDTrailer64Locator.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>

@interface ZKCDTrailer64Locator : NSObject

+ (ZKCDTrailer64Locator *) recordWithData:(NSData *)data atOffset:(UInt64)offset;
+ (ZKCDTrailer64Locator *) recordWithArchivePath:(NSString *)path andCDTrailerLength:(NSUInteger)cdTrailerLength;

- (NSData *)	data;
- (NSUInteger)	length;

@property (assign) UInt32 magicNumber;
@property (assign) UInt32 diskNumberWithStartOfCentralDirectory;
@property (assign) UInt64 offsetOfStartOfCentralDirectoryTrailer64;
@property (assign) UInt32 numberOfDisks;

@end