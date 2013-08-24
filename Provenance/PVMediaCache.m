//
//  PVMediaCache.m
//
//  Created by James Addyman on 21/02/2011.
//  Copyright 2011 JamSoft. All rights reserved.
//

#import "PVMediaCache.h"
#import "NSString+Hashing.h"

NSString * const kPVCachePath = @"PVCache";

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
			NSLog(@"Error creating cache directory at %@: %@", cachePath, [error localizedDescription]);
		}
	}
	
	return cachePath;
}

+ (UIImage *)imageForKey:(NSString *)key
{	
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
	NSString *cachePath = [self cachePath];	
	NSString *keyHash = [key MD5Hash];
	cachePath = [cachePath stringByAppendingPathComponent:keyHash];
	
	BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:cachePath];
	
	return (fileExists) ? cachePath : nil;
}

+ (NSString *)writeImageToDisk:(UIImage *)image withKey:(NSString *)key
{
	NSData *imageData = UIImagePNGRepresentation(image);
	
	return [self writeDataToDisk:imageData withKey:key];
}

+ (NSString *)writeDataToDisk:(NSData *)data withKey:(NSString *)key
{
	NSString *cachePath = [self cachePath];	
	NSString *keyHash = [key MD5Hash];
	cachePath = [cachePath stringByAppendingPathComponent:keyHash];
	
	BOOL success = [data writeToFile:cachePath atomically:YES];
	
	return (success) ? cachePath : nil;
}

+ (void)emptyCache
{
	NSLog(@"Emptying Cache");
	NSString *cachePath = [self cachePath];
	if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath])
	{
		[[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
	}
}

@end
