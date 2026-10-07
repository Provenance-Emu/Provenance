#import <QuartzCore/CAMetalLayer.h>
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

std::unique_ptr<Frontend::GraphicsContext> AzaharEmuWindow::CreateSharedContext() const {
    return std::make_unique<AzaharGraphicsContext>();
}

void AzaharEmuWindow::Resize(unsigned widthPx, unsigned heightPx, bool portrait) {
    UpdateCurrentFramebufferLayout(widthPx, heightPx, portrait);
}

void AzaharEmuWindow::Touch(bool down, float xPx, float yPx) {
    const unsigned x = xPx < 0 ? 0u : static_cast<unsigned>(xPx);
    const unsigned y = yPx < 0 ? 0u : static_cast<unsigned>(yPx);
    if (!down) {
        TouchReleased();
        return;
    }
    if (!TouchPressed(x, y)) {
        TouchMoved(x, y);
    }
}
