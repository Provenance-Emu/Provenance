//
//  emu_window_vk.h
//  emuThreeDS
//
//  Created by Antique on 27/5/2023.
//

#pragma once

#include "emu_window.h"

class EmuWindow_VK : public EmuWindow_Apple {
public:
    EmuWindow_VK(CA::MetalLayer* surface);
    ~EmuWindow_VK() override = default;
    
public:
    void TryPresenting() override;
    void DonePresenting() override;
    
    void OrientationChanged(bool portrait, CA::MetalLayer* surface);
    
    std::unique_ptr<Frontend::GraphicsContext> CreateSharedContext() const override;
    
private:
    bool CreateWindowSurface() override;
};
