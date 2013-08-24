//
//  ZKLFHeader.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>

@interface ZKLFHeader : NSObject {
@private
	NSUInteger magicNumber;
	NSUInteger versionNeededToExtract;
	NSUInteger generalPurposeBitFlag;
	NSUInteger compressionMethod;
	NSDate *lastModDate;
	NSUInteger crc;
	unsigned long long compressedSize;
	unsigned long long uncompressedSize;
	NSUInteger filenameLength;
	NSUInteger extraFieldLength;
	NSString *filename;
	NSData *extraField;
}

+ (ZKLFHeader *) recordWithData:(NSData *)data atOffset:(NSUInteger)offset;
+ (ZKLFHeader *) recordWithArchivePath:(NSString *)path atOffset:(unsigned long long)offset;
- (void) parseZip64ExtraField;
- (NSData *) zip64ExtraField;
- (NSData *) data;
- (NSUInteger) length;
- (BOOL) useZip64Extensions;
- (BOOL) isResourceFork;

@property (assign) NSUInteger magicNumber;
@property (assign) NSUInteger versionNeededToExtract;
@property (assign) NSUInteger generalPurposeBitFlag;
@property (assign) NSUInteger compressionMethod;
@property (retain) NSDate *lastModDate;
@property (assign) NSUInteger crc;
@property (assign) unsigned long long compressedSize;
@property (assign) unsigned long long uncompressedSize;
@property (assign) NSUInteger filenameLength;
@property (assign) NSUInteger extraFieldLength;
@property (copy) NSString *filename;
@property (retain) NSData *extraField;

@end