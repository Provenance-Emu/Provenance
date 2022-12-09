//
//  PVGPUViewController.h
//  Provenance
//
//  Created by Joseph Mattiello on 1/11/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#if TARGET_OS_OSX
@import SwiftUI;
@import AppKit;
#elif TARGET_OS_MACCATALYST
@import UIKit;
#else
@import UIKit;
@import GLKit;
#endif
NS_ASSUME_NONNULL_BEGIN

struct float2{ float x; float y; };
struct float4 { float x; float y; float z; float w; };

struct CRT_Data
{
    struct float4 DisplayRect;
    struct float2 EmulatedImageSize;
    struct float2 FinalRes;
};

#pragma pack(push,4)
struct SimpleCrtUniforms {
    struct float4 mame_screen_dst_rect;
    struct float4 mame_screen_src_rect;
    float curv_vert;    // 5.0 default  1.0, 10.0
    float curv_horiz;   // 4.0 default 1.0, 10.0
    float curv_strength;// 0.25 default 0.0, 1.0
    float light_boost;  // 1.3 default 0.1, 3.0
    float vign_strength;// 0.05 default 0.0, 1.0
    float zoom_out;     // 1.1 default 0.01, 5.0
    float brightness;   // 1.0 default 0.666, 1.333
};
#pragma pack(pop)

struct PVVertex
{
    GLfloat x, y, z;
    GLfloat u, v;
};

#define BUFFER_OFFSET(x) ((char *)NULL + (x))

typedef struct RenderSettings {
    BOOL crtFilterEnabled;
    BOOL lcdFilterEnabled;
    BOOL smoothingEnabled;
} RenderSettings;

#if TARGET_OS_OSX
#define BaseViewController NSViewController
#elif TARGET_OS_MACCATALYST
#define BaseViewController UIViewController
#else
@import GLKit;
#define BaseViewController GLKViewController
#endif
@class PVEmulatorCore;

@interface PVGPUViewController : BaseViewController

@property (nonatomic, retain, nullable) NSString *screenType;

#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, assign) double framesPerSecond;
@property (nonatomic, assign) NSTimeInterval timeSinceLastDraw;

#endif

@end

NS_ASSUME_NONNULL_END
