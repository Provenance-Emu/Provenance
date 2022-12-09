//
//  MupenGameCore+Mupen.h
//  MupenGameCore
//
//  Created by Joseph Mattiello on 1/26/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import <PVMupen64Plus/MupenGameCore.h>
@import Foundation;

#import "api/config.h"
#import "api/m64p_common.h"
#import "api/m64p_config.h"
#import "api/m64p_frontend.h"
#import "api/m64p_vidext.h"
#import "api/callbacks.h"
#import "osal/dynamiclib.h"
#import "Plugins/Core/src/main/version.h"
#import "Plugins/Core/src/plugin/plugin.h"

#define WIDTH 640
#define HEIGHT 480
#define WIDTHf 640.0f
#define HEIGHTf 480.0f


#if TARGET_OS_TV
#define RESIZE_TO_FULLSCREEN TRUE
#else
#define RESIZE_TO_FULLSCREEN [PVSettingsModel.shared nativeScaleEnabled]
#endif

#import <dlfcn.h>
#define N64_ANALOG_MAX 80

NS_ASSUME_NONNULL_BEGIN

void MupenAudioSampleRateChanged(int SystemType);
void MupenAudioRomClosed();
void MupenAudioRomOpen();

void MupenAudioLenChanged();
void SetIsNTSC();
int MupenOpenAudio(AUDIO_INFO info);
void MupenSetAudioSpeed(int percent);
void ConfigureAll(NSString *romFolder);
void ConfigureCore(NSString *romFolder);
void ConfigureVideoGeneral();
void ConfigureGLideN64(NSString *romFolder);
void ConfigureRICE();

@interface MupenGameCore (Mupen)
- (void)OE_addHandlerForType:(m64p_core_param)paramType usingBlock:(BOOL(^)(m64p_core_param paramType, int newValue))block;
@end

NS_ASSUME_NONNULL_END
