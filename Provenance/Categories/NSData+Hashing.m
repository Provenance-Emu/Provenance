//
//  NSData+Hashing.m
//  Provenance
//
//  Created by James Addyman on 09/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "NSData+Hashing.h"

@implementation NSData (Hashing)

- (NSString *)md5Hash
{
	unsigned char md5Digest[16];
	CC_MD5([self bytes], [self length], md5Digest);
	
	return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
			md5Digest[0], md5Digest[1],
			md5Digest[2], md5Digest[3],
			md5Digest[4], md5Digest[5],
			md5Digest[6], md5Digest[7],
			md5Digest[8], md5Digest[9],
			md5Digest[10], md5Digest[11],
			md5Digest[12], md5Digest[13],
			md5Digest[14], md5Digest[15]];
}

@end
