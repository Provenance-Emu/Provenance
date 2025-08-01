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
    if (!host_window) {
        LOG_WARNING(Frontend, "CreateWindowSurface called with null host_window");
        return false;
    }
    
    window_info.type = Frontend::WindowSystemType::MacOS;
    window_info.render_surface = host_window;
    window_info.render_surface_scale = [[UIScreen mainScreen] nativeScale];
    
    // Update window dimensions to match Metal layer's actual drawable size
    // Account for the device's native scale factor to prevent oversized viewport
    CAMetalLayer* metalLayer = (__bridge CAMetalLayer*)host_window;
    CGSize drawableSize = metalLayer.drawableSize;
    float scale = window_info.render_surface_scale;
    
    // Use logical pixels (drawable size / scale) for framebuffer layout calculation
    // This prevents the video from being too wide for the viewport
    window_width = static_cast<int>(drawableSize.width / scale);
    window_height = static_cast<int>(drawableSize.height / scale);
    
    LOG_DEBUG(Frontend, "Surface created successfully with scale: {}, drawable size: {}x{}", 
              window_info.render_surface_scale, window_width, window_height);
    return true;
}

std::unique_ptr<Frontend::GraphicsContext> EmuWindow_VK::CreateSharedContext() const {
    return std::make_unique<SharedContext_Apple>();
}

void EmuWindow_VK::OrientationChanged(bool portrait, CA::MetalLayer* surface) {
    is_portrait = portrait;
    
    // Validate surface before processing changes
    if (surface == nullptr) {
        LOG_ERROR(Frontend, "OrientationChanged called with null surface");
        return;
    }
    
    // Only update if surface actually changed
    if (host_window != surface) {
        OnSurfaceChanged(surface);
        OnFramebufferSizeChanged();
    }
}


void EmuWindow_VK::DonePresenting() {
    presenting_state = PresentingState::Stopped;
}

void EmuWindow_VK::TryPresenting() {
    static int frame_count = 0;
    frame_count++;
    
    LOG_DEBUG(Frontend, "TryPresenting called, frame #{}, state: {}", frame_count, static_cast<int>(presenting_state));
    
    if (presenting_state != PresentingState::Running) {
        if (presenting_state == PresentingState::Initial) {
            LOG_INFO(Frontend, "Starting presentation (Initial -> Running) on frame #{}", frame_count);
            presenting_state = PresentingState::Running;
        } else {
            LOG_WARNING(Frontend, "Skipping presentation on frame #{}, state: {}", frame_count, static_cast<int>(presenting_state));
            return;
        }
    }

    Core::System& system{Core::System::GetInstance()};

    // Use try-catch to handle any renderer issues safely
    try {
        LOG_DEBUG(Frontend, "Calling GPU().Renderer().TryPresent(0) for frame #{}", frame_count);
        system.GPU().Renderer().TryPresent(0);
        LOG_DEBUG(Frontend, "GPU().Renderer().TryPresent(0) completed successfully for frame #{}", frame_count);
    } catch (const std::exception& e) {
        LOG_ERROR(Frontend, "TryPresenting failed on frame #{}: {}", frame_count, e.what());
    } catch (...) {
        LOG_ERROR(Frontend, "TryPresenting failed on frame #{} with unknown exception", frame_count);
    }
}
