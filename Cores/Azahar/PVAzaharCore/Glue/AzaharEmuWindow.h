#pragma once
#include <memory>
#include "core/frontend/emu_window.h"
#ifdef __OBJC__
@class CAMetalLayer;
#else
typedef struct objc_object CAMetalLayer;
#endif

class AzaharEmuWindow final : public Frontend::EmuWindow {
public:
    AzaharEmuWindow(CAMetalLayer* layer, float scale, unsigned widthPx, unsigned heightPx, bool portrait);
    ~AzaharEmuWindow() override;

    void PollEvents() override {}
    void MakeCurrent() override {}
    void DoneCurrent() override {}
    std::unique_ptr<Frontend::GraphicsContext> CreateSharedContext() const override;
    /// Vulkan::Instance opens the driver through the window itself (`OpenLibrary(&window)`),
    /// not the shared context, so the window must hand out MoltenVK too.
    std::shared_ptr<Common::DynamicLibrary> GetDriverLibrary() override;

    /// Call from the emulation thread (the bridge queues it) after the layer's drawableSize changed.
    void Resize(unsigned widthPx, unsigned heightPx, bool portrait);
    /// Window-pixel coordinates; azahar maps them to the bottom screen through the active layout.
    void Touch(bool down, float xPx, float yPx);
};
