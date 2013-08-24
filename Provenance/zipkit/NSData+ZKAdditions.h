//
//  NSData+ZKAdditions.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>

@interface NSData (ZKAdditions)

- (UInt16) zk_hostInt16OffsetBy:(NSUInteger *)offset;
- (UInt32) zk_hostInt32OffsetBy:(NSUInteger *)offset;
- (UInt64) zk_hostInt64OffsetBy:(NSUInteger *)offset;
- (BOOL) zk_hostBoolOffsetBy:(NSUInteger *) offset;
- (NSString *) zk_stringOffsetBy:(NSUInteger *)offset length:(NSUInteger)length;
- (NSUInteger) zk_crc32;
- (NSUInteger) zk_crc32:(NSUInteger)crc;
- (NSData *) zk_inflate;
- (NSData *) zk_deflate;

@end

@interface NSMutableData (ZKAdditions)

+ (NSMutableData *) zk_dataWithLittleInt16:(UInt16)value;
+ (NSMutableData *) zk_dataWithLittleInt32:(UInt32)value;
+ (NSMutableData *) zk_dataWithLittleInt64:(UInt64)value;

- (void) zk_appendLittleInt16:(UInt16)value;
- (void) zk_appendLittleInt32:(UInt32)value;
- (void) zk_appendLittleInt64:(UInt64)value;
- (void) zk_appendLittleBool:(BOOL) value;
- (void) zk_appendPrecomposedUTF8String:(NSString *)value;

@end