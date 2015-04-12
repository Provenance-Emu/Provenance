//
//  NSData+Hashing.h
//  Provenance
//
//  Created by James Addyman on 09/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (Hashing)

- (NSString *)md5Hash;
- (NSString *)sha1Hash;

@end
