//
// PPSSPP View Controller
// Created by rock88 Modified by xSacha
// Copyright (c) 2012- PPSSPP Project.
//

#import "PVPPSSPPCore.h"
#import "PVPPSSPPCore+Controls.h"
#import "PVPPSSPPCore+Audio.h"
#import "PVPPSSPPCore+Video.h"
#import <PVPPSSPP/PVPPSSPP-Swift.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <PVLogging/PVLogging.h>

/* PPSSPP Includes */
#import <dlfcn.h>
#import <pthread.h>
#import <signal.h>
#import <string>
#import <stdio.h>
#import <stdlib.h>
#import <sys/syscall.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <mach/machine.h>

#include "Common/MemoryUtil.h"
#include "Common/Profiler/Profiler.h"
#include "Common/CPUDetect.h"
#include "Common/Log.h"
#include "Common/LogManager.h"
#include "Common/TimeUtil.h"
#include "Common/File/FileUtil.h"
#include "Common/Serialize/Serializer.h"
#include "Common/ConsoleListener.h"
#include "Common/Input/InputState.h"
#include "Common/Input/KeyCodes.h"
#include "Common/Thread/ThreadUtil.h"
#include "Common/Thread/ThreadManager.h"
#include "Common/File/VFS/VFS.h"
#include "Common/Data/Text/I18n.h"
#include "Common/StringUtils.h""
#include "Common/System/Display.h"
#include "Common/System/NativeApp.h"
#include "Common/System/System.h"
#include "Common/GraphicsContext.h"
#include "Common/Net/Resolve.h"
#include "Common/UI/Screen.h"
#include "Common/GPU/thin3d.h"
#include "Common/GPU/thin3d_create.h"
#include "Common/GPU/OpenGL/GLRenderManager.h"
#include "Common/GPU/OpenGL/GLFeatures.h"
#include "Common/System/NativeApp.h"
#include "Common/File/VFS/VFS.h"
#include "Common/Log.h"
#include "Common/TimeUtil.h"
#include "Common/GraphicsContext.h"

#include "GPU/GPUState.h"
#include "GPU/GPUInterface.h""

#include "Core/Config.h"
#include "Core/ConfigValues.h"
#include "Core/Core.h"
#include "Core/CoreParameter.h"
#include "Core/HLE/sceCtrl.h"
#include "Core/HLE/sceUtility.h"
#include "Core/HW/MemoryStick.h"
#include "Core/MemMap.h"
#include "Core/System.h"
#include "Core/CoreTiming.h"
#include "Core/HW/Display.h"
#include "Core/CwCheat.h"
#include "Core/ELF/ParamSFO.h"

void bindDefaultFBO();

class OGLGraphicsContext : public GraphicsContext {
public:
    OGLGraphicsContext() {
        CheckGLExtensions();
        draw_ = Draw::T3DCreateGLContext();
        renderManager_ = (GLRenderManager *)draw_->GetNativeObject(Draw::NativeObject::RENDER_MANAGER);
        renderManager_->SetInflightFrames(g_Config.iInflightFrames);
        SetGPUBackend(GPUBackend::OPENGL);
        bool success = draw_->CreatePresets();
        if (success) {
            NSLog(@"Shader preset ok\n");
        } else {
            NSLog(@"Shader preset failed\n");
        }
        _assert_msg_(success, "Failed to compile preset shaders");
    }
    ~OGLGraphicsContext() {
        //delete draw_;
    }
    Draw::DrawContext *GetDrawContext() override {
        return draw_;
    }

    void SwapInterval(int interval) override {}
    void SwapBuffers() override {}
    void Resize() override {}
    void Shutdown() override {}

    void ThreadStart() override {
        renderManager_->ThreadStart(draw_);
    }

    bool ThreadFrame() override {
        return renderManager_->ThreadFrame();
    }

    void ThreadEnd() override {
        renderManager_->ThreadEnd();
    }

    void StopThread() override {
        renderManager_->StopThread();
    }

private:
    Draw::DrawContext *draw_;
    GLRenderManager *renderManager_;
};
