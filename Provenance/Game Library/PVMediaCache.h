//  Created by James Addyman on 21/02/2011.
//  Copyright 2011 JamSoft. All rights reserved.
//

#import <UIKit/UIKit.h>

#if TARGET_OS_TV
static const float PVThumbnailMaxResolution = 400.0;
#else
static const float PVThumbnailMaxResolution = 200.0;
#endif

extern NSString * _Nonnull const kPVCachePath;

extern NSString * _Nonnull const PVMediaCacheWasEmptiedNotification;

@interface PVMediaCache : NSObject {
    
}

+ (instancetype _Nonnull)shareInstance;

+ (NSString * _Nonnull)cachePath;
- (NSBlockOperation *_Nullable)imageForKey:(NSString * _Nonnull)key completion:(void(^_Nullable)(UIImage * _Nullable image))completion;
+ (NSString * _Nullable)filePathForKey:(NSString * _Nonnull)key;
+ (NSString * _Nullable)writeImageToDisk:(UIImage * _Nonnull)image withKey:(NSString * _Nonnull) _Nonnullkey;
+ (NSString * _Nullable)writeDataToDisk:(NSData * _Nonnull)data withKey:(NSString * _Nonnull)key;
+ (BOOL)deleteImageForKey:(NSString * _Nonnull)key;
+ (void)emptyCache;

@end
