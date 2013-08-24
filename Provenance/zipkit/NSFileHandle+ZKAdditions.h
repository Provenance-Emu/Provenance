//
//  NSFileHandle+ZKAdditions.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>

@interface NSFileHandle (ZKAdditions)

+ (NSFileHandle *) zk_newFileHandleForWritingAtPath:(NSString *)path;

@end