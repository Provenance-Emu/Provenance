#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include "AzaharGraphicsContext.h"

std::shared_ptr<Common::DynamicLibrary> AzaharMoltenVKLibrary() {
    static std::shared_ptr<Common::DynamicLibrary> library = [] {
        void* handle = dlopen("@rpath/MoltenVK.framework/MoltenVK", RTLD_NOW | RTLD_GLOBAL);
        if (!handle) {
            // @rpath resolution depends on the caller's LC_RPATH; fall back to the app's own
            // Frameworks directory, where the MoltenVK.framework is embedded.
            NSString* path = [[NSBundle mainBundle].privateFrameworksPath
                stringByAppendingPathComponent:@"MoltenVK.framework/MoltenVK"];
            handle = dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_GLOBAL);
        }
        if (!handle) {
            NSLog(@"[PVAzahar] dlopen MoltenVK failed: %s", dlerror());
            return std::shared_ptr<Common::DynamicLibrary>{};
        }
        NSLog(@"[PVAzahar] MoltenVK loaded");
        return std::make_shared<Common::DynamicLibrary>(handle);
    }();
    return library;
}
