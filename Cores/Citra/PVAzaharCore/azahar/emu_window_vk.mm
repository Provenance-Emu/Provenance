//
//  emu_window_vk.cpp
//  emuThreeDS
//
//  Created by Antique on 27/5/2023.
//

#include "emu_window_vk.h"
#include "video_core/renderer_base.h"
#include "video_core/video_core.h"
#include "video_core/gpu.h"
#include "common/settings.h"
#include "core/core.h"

#import <UIKit/UIKit.h>

class SharedContext_Apple : public Frontend::GraphicsContext {};


EmuWindow_VK::EmuWindow_VK(CA::MetalLayer* surface) : EmuWindow_Apple{surface} {
    CreateWindowSurface();
    core_context = CreateSharedContext();
    
    OnFramebufferSizeChanged();
}

bool EmuWindow_VK::CreateWindowSurface() {
    if (!host_window)
        return true;
    
    window_info.type = Frontend::WindowSystemType::MacOS;
    window_info.render_surface = host_window;
    window_info.render_surface_scale = [[UIScreen mainScreen] nativeScale];

    return true;
}

std::unique_ptr<Frontend::GraphicsContext> EmuWindow_VK::CreateSharedContext() const {
    return std::make_unique<SharedContext_Apple>();
}

void EmuWindow_VK::OrientationChanged(bool portrait, CA::MetalLayer* surface) {
    is_portrait = portrait;
    
    OnSurfaceChanged(surface);
    OnFramebufferSizeChanged();
}


void EmuWindow_VK::DonePresenting() {
    presenting_state = PresentingState::Stopped;
}

void EmuWindow_VK::TryPresenting() {
    if (presenting_state != PresentingState::Running) {
        if (presenting_state == PresentingState::Initial) {
            presenting_state = PresentingState::Running;
        } else {
            return;
        }
    }

    Core::System& system{Core::System::GetInstance()};

    // FIXME: @JoeMatt
//    if (system.GPU().Renderer() != nullptr) {
        system.GPU().Renderer().TryPresent(0);
//    }
}
