#include "../../libretro_ppsspp/ppsspp_config.h"

// The archive left this x86-only object unloaded on ARM. SwiftPM links source
// targets as whole objects, so match ABI.cpp's architecture guard explicitly.
#if PPSSPP_ARCH(X86) || PPSSPP_ARCH(AMD64)
#include "../../libretro_ppsspp/Common/Thunk.cpp"
#endif
