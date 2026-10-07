#pragma once
#include <memory>
#include "common/dynamic_library.h"
#include "core/frontend/emu_window.h"

/// The app embeds MoltenVK.framework (MoltenVK/MoltenVK/dynamic). azahar's loader cannot
/// find it by bare name on iOS, so we dlopen it once and hand the handle over (patch 2).
/// Returns nullptr if dlopen fails.
std::shared_ptr<Common::DynamicLibrary> AzaharMoltenVKLibrary();

class AzaharGraphicsContext final : public Frontend::GraphicsContext {
public:
    std::shared_ptr<Common::DynamicLibrary> GetDriverLibrary() override { return AzaharMoltenVKLibrary(); }
};
