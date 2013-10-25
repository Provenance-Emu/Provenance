//
//  ZKLFHeader.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>

@interface ZKLFHeader : NSObject

+ (ZKLFHeader *) recordWithData:(NSData *)data atOffset:(UInt64)offset;
+ (ZKLFHeader *) recordWithArchivePath:(NSString *)path atOffset:(UInt64)offset;
- (void)                parseZip64ExtraField;
- (NSData *)            zip64ExtraField;
- (NSData *)            data;
- (NSUInteger)          length;
- (BOOL)                useZip64Extensions;
- (BOOL)                isResourceFork;

@property (assign) UInt32 magicNumber;
@property (assign) UInt32 versionNeededToExtract;
@property (assign) UInt32 generalPurposeBitFlag;
@property (assign) UInt32 compressionMethod;
@property (strong) NSDate *lastModDate;
@property (assign) UInt32 crc;
@property (assign) UInt64 compressedSize;
@property (assign) UInt64 uncompressedSize;
@property (assign) UInt32 filenameLength;
@property (assign) UInt32 extraFieldLength;
@property (copy) NSString *filename;
@property (strong) NSData *extraField;

@end