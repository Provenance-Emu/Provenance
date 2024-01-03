//
//  emu_window.h
//  emuThreeDS
//
//  Created by Antique on 27/5/2023.
//

#pragma once

#include <vector>

#include "Metal/Metal.hpp"
#include "core/frontend/emu_window.h"

class EmuWindow_Apple : public Frontend::EmuWindow {
public:
    EmuWindow_Apple(CA::MetalLayer* surface);
    ~EmuWindow_Apple();
    
    void MakeCurrent() override;
    void DoneCurrent() override;
    
    void OnSurfaceChanged(CA::MetalLayer* surface);
    
    
    bool OnTouchEvent(int x, int y, bool pressed);
    void OnTouchMoved(int x, int y);
    void OnTouchReleased();
    
    void PollEvents() override;
    
    virtual void TryPresenting() = 0;
    virtual void DonePresenting() = 0;
    
    bool is_portrait;
    
    void OnFramebufferSizeChanged();
    
    virtual bool CreateWindowSurface() { return true; }
    virtual void DestroyWindowSurface() {}
    virtual void DestroyContext() {}
    
    CA::MetalLayer* render_window, *host_window;
    std::unique_ptr<Frontend::GraphicsContext> core_context;
    int window_width, window_height;
    
    enum class PresentingState {
            Initial,
            Running,
            Stopped,
        };
        PresentingState presenting_state{};
};
