//
//  PVFBNeoCore.h
//  PVFBNeo
//
//  Created by Joseph Mattiello on 10/20/21.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>


#import <PVCoreBridgeRetro/PVCoreBridgeRetro.h>
#import <PVCoreObjCBridge/PVCoreObjCBridge.h>

#define GET_CURRENT_AND_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;
#define GET_CURRENT_OR_RETURN(...)  __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
__attribute__((visibility("default")))
@interface PVFBNeoCore : PVLibRetroCoreBridge <PVColecoVisionSystemResponderClient>
#pragma clang diagnostic pop

@end

@protocol FBVideoDelegate<NSObject>

@optional
- (void) screenSizeDidChange:(CGSize) newSize;
- (void) initTextureOfWidth:(int) width
                     height:(int) height
                  isRotated:(BOOL) rotated
                  isFlipped:(BOOL) flipped
              bytesPerPixel:(int) bytesPerPixel;
- (void) renderFrame:(unsigned char *) bitmap;

@end

@interface FBVideo : NSObject

@property (nonatomic, weak) id<FBVideoDelegate> delegate;

- (CGSize) gameScreenSize;

@end
