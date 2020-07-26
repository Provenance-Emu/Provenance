//
//  NSFileManager+NSFileManager_Hashing.m
//  Provenance
//
//  Created by James Addyman on 11/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "NSFileManager+Hashing.h"
#import <CommonCrypto/CommonDigest.h>

#define HASH_READ_CHUNK_SIZE (1024 * 32)

# define SWAP(n)							\
(((n) << 24) | (((n) & 0xff00) << 8) | (((n) >> 8) & 0xff00) | ((n) >> 24))

@implementation NSFileManager (Hashing)

- (NSString *)MD5ForFileAtPath:(NSString *)path fromOffset:(NSUInteger)offset
{
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle)
    {
        return nil;
    }
    
    [handle seekToFileOffset:offset];
    
    CC_MD5_CTX md5Context;
    CC_MD5_Init(&md5Context);
    
    do {
        @autoreleasepool
        {
            NSData *data = [handle readDataOfLength:HASH_READ_CHUNK_SIZE];
            const unsigned char *bytes = [data bytes];
            NSUInteger length = [data length];
            CC_MD5_Update(&md5Context, bytes, (CC_LONG)length);

			// Btye-swapping for things like z64? - joe m
//			md5Context.A = SWAP(md5Context.A);
//			md5Context.B = SWAP(md5Context.B);
//			md5Context.C = SWAP(md5Context.C);
//			md5Context.D = SWAP(md5Context.D);

			if (data == nil || length < HASH_READ_CHUNK_SIZE)
            {
                break;
            }
        }
    } while (YES);
    
    [handle closeFile];
    
    // Finalize MD5
    unsigned char md5Digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(md5Digest, &md5Context);
    
    return [[NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            md5Digest[0], md5Digest[1],
            md5Digest[2], md5Digest[3],
            md5Digest[4], md5Digest[5],
            md5Digest[6], md5Digest[7],
            md5Digest[8], md5Digest[9],
            md5Digest[10], md5Digest[11],
            md5Digest[12], md5Digest[13],
            md5Digest[14], md5Digest[15]] uppercaseString];
}

@end
