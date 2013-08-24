//
//  ZKCDTrailer64Locator.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>

@interface ZKCDTrailer64Locator : NSObject {
@private
	NSUInteger magicNumber;
	NSUInteger diskNumberWithStartOfCentralDirectory;
	unsigned long long offsetOfStartOfCentralDirectoryTrailer64;
	NSUInteger numberOfDisks;
}

+ (ZKCDTrailer64Locator *) recordWithData:(NSData *)data atOffset:(NSUInteger) offset;
+ (ZKCDTrailer64Locator *) recordWithArchivePath:(NSString *)path andCDTrailerLength:(NSUInteger)cdTrailerLength;

- (NSData *) data;
- (NSUInteger) length;

@property (assign) NSUInteger magicNumber;
@property (assign) NSUInteger diskNumberWithStartOfCentralDirectory;
@property (assign) unsigned long long offsetOfStartOfCentralDirectoryTrailer64;
@property (assign) NSUInteger numberOfDisks;

@end