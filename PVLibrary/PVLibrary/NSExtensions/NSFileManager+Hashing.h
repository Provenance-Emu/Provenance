//
//  NSFileManager+NSFileManager_Hashing.h
//  Provenance
//
//  Created by James Addyman on 11/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSFileManager (Hashing)

- (NSString *_Nullable)MD5ForFileAtPath:(NSString *_Nonnull)path fromOffset:(NSUInteger)offset;

@end
