//
//  NSDictionary+ZKAdditions.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (ZKAdditions)

+ (NSDictionary *) zk_totalSizeAndCountDictionaryWithSize:(UInt64)size andItemCount:(UInt64)count;
- (UInt64)              zk_totalFileSize;
- (UInt64)              zk_itemCount;

@end