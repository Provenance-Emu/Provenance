//  Created by James Addyman on 21/02/2011.
//  Copyright 2011 JamSoft. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString * const kPVCachePath;

extern NSString * const PVMediaCacheWasEmptiedNotification;

@interface PVMediaCache : NSObject {
    
}

+ (NSString *)cachePath;
+ (UIImage *)imageForKey:(NSString *)key;
+ (NSString *)filePathForKey:(NSString *)key;
+ (NSString *)writeImageToDisk:(UIImage *)image withKey:(NSString *)key;
+ (NSString *)writeDataToDisk:(NSData *)data withKey:(NSString *)key;
+ (BOOL)deleteImageForKey:(NSString *)key;
+ (void)emptyCache;

@end
