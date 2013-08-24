//
//  NSDate+ZKAdditions.h
//  ZipKit
//
//  Created by Karl Moskowski on 01/04/09.
//

#import <Foundation/Foundation.h>

@interface NSDate (ZKAdditions)

+ (NSDate *) zk_dateWithDosDate:(NSUInteger) dosDate;
- (NSUInteger) zk_dosDate;

@end
