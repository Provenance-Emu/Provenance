//
//  NSFileManager+ZKAdditions.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>
#import "ZKDefs.h"

@interface NSFileManager (ZKAdditions)

- (BOOL) zk_isSymLinkAtPath:(NSString *) path;
- (BOOL) zk_isDirAtPath:(NSString *) path;

- (unsigned long long) zk_dataSizeAtFilePath:(NSString *) path;
- (NSDictionary *) zkTotalSizeAndItemCountAtPath:(NSString *) path usingResourceFork:(BOOL) rfFlag;
#if ZK_TARGET_OS_MAC
- (void) zk_combineAppleDoubleInDirectory:(NSString *) path;
#endif

- (NSDate *) zk_modificationDateForPath:(NSString *) path;
- (NSUInteger) zk_posixPermissionsAtPath:(NSString *) path;
- (NSUInteger) zk_externalFileAttributesAtPath:(NSString *) path;
- (NSUInteger) zk_externalFileAttributesFor:(NSDictionary *) fileAttributes;

- (NSUInteger) zk_crcForPath:(NSString *) path;
- (NSUInteger) zk_crcForPath:(NSString *) path invoker:(id) invoker;
- (NSUInteger) zk_crcForPath:(NSString *) path invoker:(id)invoker;
- (NSUInteger) zk_crcForPath:(NSString *)path invoker:(id)invoker throttleThreadSleepTime:(NSTimeInterval) throttleThreadSleepTime;

@end