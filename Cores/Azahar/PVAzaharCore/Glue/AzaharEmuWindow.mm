#import <QuartzCore/CAMetalLayer.h>
#include <cmath>
#include "AzaharEmuWindow.h"
#include "AzaharGraphicsContext.h"

AzaharEmuWindow::AzaharEmuWindow(CAMetalLayer* layer, float scale, unsigned widthPx, unsigned heightPx, bool portrait)
    : Frontend::EmuWindow(false) {
    window_info.type = Frontend::WindowSystemType::MacOS; // CAMetalLayer surface path in vk_platform
    window_info.render_surface = (__bridge void*)layer;
    window_info.render_surface_scale = scale;
    UpdateCurrentFramebufferLayout(widthPx, heightPx, portrait);
}

AzaharEmuWindow::~AzaharEmuWindow() = default;

std::shared_ptr<Common::DynamicLibrary> AzaharEmuWindow::GetDriverLibrary() {
    return AzaharMoltenVKLibrary();
}

std::unique_ptr<Frontend::GraphicsContext> AzaharEmuWindow::CreateSharedContext() const {
    return std::make_unique<AzaharGraphicsContext>();
}

void AzaharEmuWindow::Resize(unsigned widthPx, unsigned heightPx, bool portrait) {
    UpdateCurrentFramebufferLayout(widthPx, heightPx, portrait);
}

void AzaharEmuWindow::Touch(bool down, float xPx, float yPx) {
    if (!std::isfinite(xPx) || !std::isfinite(yPx)) {
        return;   // casting NaN/inf to unsigned is undefined
    }
    const unsigned x = xPx < 0 ? 0u : static_cast<unsigned>(xPx);
    const unsigned y = yPx < 0 ? 0u : static_cast<unsigned>(yPx);
    if (!down) {
        TouchReleased();
        return;
    }
    // TouchPressed is false outside the bottom screen; TouchMoved then clips a held touch to the
    // screen edge and ignores a fresh one, which is the behaviour we want for both.
    if (!TouchPressed(x, y)) {
        TouchMoved(x, y);
    }
}
