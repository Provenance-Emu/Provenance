//
//  ZKCDHeader.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>

@interface ZKCDHeader : NSObject

+ (ZKCDHeader *) recordWithData:(NSData *)data atOffset:(UInt64)offset;
+ (ZKCDHeader *) recordWithArchivePath:(NSString *)path atOffset:(UInt64)offset;
- (void)                parseZip64ExtraField;
- (NSData *)            zip64ExtraField;
- (NSData *)            data;
- (NSUInteger)          length;
- (BOOL)                useZip64Extensions;
- (NSNumber *)          posixPermissions;
- (BOOL)                isDirectory;
- (BOOL)                isSymLink;
- (BOOL)                isResourceFork;

@property (assign) UInt32 magicNumber;
@property (assign) UInt32 versionMadeBy;
@property (assign) UInt32 versionNeededToExtract;
@property (assign) UInt32 generalPurposeBitFlag;
@property (assign) UInt32 compressionMethod;
@property (strong) NSDate *lastModDate;
@property (assign) UInt32 crc;
@property (assign) UInt64 compressedSize;
@property (assign) UInt64 uncompressedSize;
@property (assign) UInt32 filenameLength;
@property (assign) UInt32 extraFieldLength;
@property (assign) UInt32 commentLength;
@property (assign) UInt32 diskNumberStart;
@property (assign) UInt32 internalFileAttributes;
@property (assign) UInt32 externalFileAttributes;
@property (assign) UInt64 localHeaderOffset;
@property (copy) NSString *filename;
@property (strong) NSData *extraField;
@property (copy) NSString *comment;
@property (strong) NSMutableData *cachedData;

@end