#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include "AzaharGraphicsContext.h"

std::shared_ptr<Common::DynamicLibrary> AzaharMoltenVKLibrary() {
    static std::shared_ptr<Common::DynamicLibrary> library = [] {
        void* handle = dlopen("@rpath/MoltenVK.framework/MoltenVK", RTLD_NOW | RTLD_GLOBAL);
        if (!handle) {
            NSLog(@"[PVAzahar] dlopen MoltenVK failed: %s", dlerror());
            return std::shared_ptr<Common::DynamicLibrary>{};
        }
        return std::make_shared<Common::DynamicLibrary>(handle);
    }();
    return library;
}
