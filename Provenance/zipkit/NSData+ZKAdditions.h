//
//  NSData+ZKAdditions.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>

@interface NSData (ZKAdditions)

- (UInt16) zk_hostInt16OffsetBy:(UInt64 *)offset;
- (UInt32) zk_hostInt32OffsetBy:(UInt64 *)offset;
- (UInt64) zk_hostInt64OffsetBy:(UInt64 *)offset;
- (BOOL) zk_hostBoolOffsetBy:(UInt64 *)offset;
- (NSString *) zk_stringOffsetBy:(UInt64 *)offset length:(NSUInteger)length;
- (unsigned long)       zk_crc32;
- (unsigned long) zk_crc32:(unsigned long)crc;
- (NSData *)            zk_inflate;
- (NSData *)            zk_deflate;

@end

@interface NSMutableData (ZKAdditions)

+ (NSMutableData *) zk_dataWithLittleInt16:(UInt16)value;
+ (NSMutableData *) zk_dataWithLittleInt32:(UInt32)value;
+ (NSMutableData *) zk_dataWithLittleInt64:(UInt64)value;

- (void) zk_appendLittleInt16:(UInt16)value;
- (void) zk_appendLittleInt32:(UInt32)value;
- (void) zk_appendLittleInt64:(UInt64)value;
- (void) zk_appendLittleBool:(BOOL)value;
- (void) zk_appendPrecomposedUTF8String:(NSString *)value;

@end