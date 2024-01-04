//
//  emu_window.cpp
//  emuThreeDS
//
//  Created by Antique on 27/5/2023.
//

#include "emu_window.h"

#include "network/network.h"

#include "video_core/renderer_base.h"
#include "video_core/video_core.h"

#include "file_handle.h"

EmuWindow_Apple::EmuWindow_Apple(CA::MetalLayer* surface) : host_window{surface} {
    // window width, height
    window_width = ResolutionHandle::GetScreenWidth();
    window_height = ResolutionHandle::GetScreenHeight();
    is_portrait = false;
    
    Network::Init();
}

EmuWindow_Apple::~EmuWindow_Apple() {
    DestroyWindowSurface();
    DestroyContext();
}

void EmuWindow_Apple::OnFramebufferSizeChanged() {
    const int bigger{window_width > window_height ? window_width : window_height};
    const int smaller{window_width < window_height ? window_width : window_height};
    if (is_portrait) {
        UpdateCurrentFramebufferLayout(smaller, bigger, is_portrait);
    } else {
        UpdateCurrentFramebufferLayout(bigger, smaller, is_portrait);
    }
}


void EmuWindow_Apple::OnSurfaceChanged(CA::MetalLayer *surface) {
    render_window = surface;
    
    window_info.type = Frontend::WindowSystemType::MacOS;
    window_info.render_surface = surface;
    
    DonePresenting();
}


bool EmuWindow_Apple::OnTouchEvent(int x, int y, bool pressed) {
    return TouchPressed((unsigned)std::max(x, 0), (unsigned)std::max(y, 0));
}

void EmuWindow_Apple::OnTouchMoved(int x, int y) {
    TouchMoved((unsigned)x, (unsigned)y);
}

void EmuWindow_Apple::OnTouchReleased() {
    TouchReleased();
}


void EmuWindow_Apple::PollEvents() {
    if (!render_window)
        return;
    
    host_window = render_window;
    render_window = nullptr;
    
    DestroyWindowSurface();
    CreateWindowSurface();
    OnFramebufferSizeChanged();
    presenting_state = PresentingState::Initial;
}

void EmuWindow_Apple::MakeCurrent() {
    core_context->MakeCurrent();
}

void EmuWindow_Apple::DoneCurrent() {
    core_context->DoneCurrent();
}
