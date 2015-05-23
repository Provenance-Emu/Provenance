//
//  PVMediaCache.m
//
//  Created by James Addyman on 21/02/2011.
//  Copyright 2011 JamSoft. All rights reserved.
//

#import "PVMediaCache.h"
#import "NSString+Hashing.h"

NSString * const kPVCachePath = @"PVCache";

NSString * const PVMediaCacheWasEmptiedNotification = @"PVMediaCacheWasEmptiedNotification";

@implementation PVMediaCache

+ (NSString *)cachePath
{
	NSString *cachePath = nil;
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	if ([paths count])
	{
		cachePath = [paths objectAtIndex:0];
	}
	
	cachePath = [cachePath stringByAppendingPathComponent:kPVCachePath];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:cachePath])
	{
		NSError *error = nil;
		[[NSFileManager defaultManager] createDirectoryAtPath:cachePath
								  withIntermediateDirectories:YES
												   attributes:nil
														error:&error];
		if (error)
		{
			DLog(@"Error creating cache directory at %@: %@", cachePath, [error localizedDescription]);
		}
	}
	
	return cachePath;
}

+ (UIImage *)imageForKey:(NSString *)key
{
    if (![key length])
    {
        return nil;
    }
    
	NSString *cachePath = [self cachePath];	
	NSString *keyHash = [key MD5Hash];
	cachePath = [cachePath stringByAppendingPathComponent:keyHash];
	
	UIImage *image = nil;
	if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath])
	{
		image = [UIImage imageWithContentsOfFile:cachePath];
	}
	
	return image;
}

+ (NSString *)filePathForKey:(NSString *)key
{
    if (![key length])
    {
        return nil;
    }
    
	NSString *cachePath = [self cachePath];
	NSString *keyHash = [key MD5Hash];
	cachePath = [cachePath stringByAppendingPathComponent:keyHash];
	
	BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:cachePath];
	
	return (fileExists) ? cachePath : nil;
}

+ (NSString *)writeImageToDisk:(UIImage *)image withKey:(NSString *)key
{
    if (!image || ![key length])
    {
        return nil;
    }
    
	NSData *imageData = UIImagePNGRepresentation(image);
	
	return [self writeDataToDisk:imageData withKey:key];
}

+ (NSString *)writeDataToDisk:(NSData *)data withKey:(NSString *)key
{
    if (![key length])
    {
        return nil;
    }
    
	NSString *cachePath = [self cachePath];
	NSString *keyHash = [key MD5Hash];
	cachePath = [cachePath stringByAppendingPathComponent:keyHash];
	
	BOOL success = [data writeToFile:cachePath atomically:YES];
	
	return (success) ? cachePath : nil;
}

+ (BOOL)deleteImageForKey:(NSString *)key
{
    if (![key length])
    {
        return NO;
    }
    
	NSString *cachePath = [self cachePath];
	NSString *keyHash = [key MD5Hash];
	cachePath = [cachePath stringByAppendingPathComponent:keyHash];
	NSError *error = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath])
    {
        if (![[NSFileManager defaultManager] removeItemAtPath:cachePath error:&error])
        {
            DLog(@"Unable to delete cache item: %@ because: %@", cachePath, [error localizedDescription]);
            return NO;
        }
    }
	
	return YES;
}

+ (void)emptyCache
{
	DLog(@"Emptying Cache");
	NSString *cachePath = [self cachePath];
	if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath])
	{
		[[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:PVMediaCacheWasEmptiedNotification object:nil];
}

@end
