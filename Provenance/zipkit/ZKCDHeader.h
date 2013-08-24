//
//  ZKCDHeader.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>

@interface ZKCDHeader : NSObject {
@private
	NSUInteger magicNumber;
	NSUInteger versionMadeBy;
	NSUInteger versionNeededToExtract;
	NSUInteger generalPurposeBitFlag;
	NSUInteger compressionMethod;
	NSDate *lastModDate;
	NSUInteger crc;
	unsigned long long compressedSize;
	unsigned long long uncompressedSize;
	NSUInteger filenameLength;
	NSUInteger extraFieldLength;
	NSUInteger commentLength;
	NSUInteger diskNumberStart;
	NSUInteger internalFileAttributes;
	NSUInteger externalFileAttributes;
	unsigned long long localHeaderOffset;
	NSString *filename;
	NSData *extraField;
	NSString *comment;
	NSMutableData *cachedData;
}

+ (ZKCDHeader *) recordWithData:(NSData *)data atOffset:(NSUInteger)offset;
+ (ZKCDHeader *) recordWithArchivePath:(NSString *)path atOffset:(unsigned long long)offset;
- (void) parseZip64ExtraField;
- (NSData *) zip64ExtraField;
- (NSData *) data;
- (NSUInteger) length;
- (BOOL) useZip64Extensions;
- (NSNumber *) posixPermissions;
- (BOOL) isDirectory;
- (BOOL) isSymLink;
- (BOOL) isResourceFork;

@property (assign) NSUInteger magicNumber;
@property (assign) NSUInteger versionMadeBy;
@property (assign) NSUInteger versionNeededToExtract;
@property (assign) NSUInteger generalPurposeBitFlag;
@property (assign) NSUInteger compressionMethod;
@property (retain) NSDate *lastModDate;
@property (assign) NSUInteger crc;
@property (assign) unsigned long long compressedSize;
@property (assign) unsigned long long uncompressedSize;
@property (assign) NSUInteger filenameLength;
@property (assign) NSUInteger extraFieldLength;
@property (assign) NSUInteger commentLength;
@property (assign) NSUInteger diskNumberStart;
@property (assign) NSUInteger internalFileAttributes;
@property (assign) NSUInteger externalFileAttributes;
@property (assign) unsigned long long localHeaderOffset;
@property (copy) NSString *filename;
@property (retain) NSData *extraField;
@property (copy) NSString *comment;
@property (retain) NSMutableData *cachedData;

@end