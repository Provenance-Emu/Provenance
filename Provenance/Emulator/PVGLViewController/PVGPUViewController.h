//
//  PVGPUViewController.h
//  Provenance
//
//  Created by Joseph Mattiello on 1/11/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

struct float2{ float x; float y; };
struct float4 { float x; float y; float z; float w; };

struct CRT_Data
{
    struct float4 DisplayRect;
    struct float2 EmulatedImageSize;
    struct float2 FinalRes;
};

struct PVVertex
{
    GLfloat x, y, z;
    GLfloat u, v;
};

#define BUFFER_OFFSET(x) ((char *)NULL + (x))

typedef struct RenderSettings {
    BOOL crtFilterEnabled;
    BOOL smoothingEnabled;
} RenderSettings;

#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
#define BaseViewController UIViewController
#else
@import GLKit;
#define BaseViewController GLKViewController
#endif
@class PVEmulatorCore;

@interface PVGPUViewController : BaseViewController

@end

NS_ASSUME_NONNULL_END
