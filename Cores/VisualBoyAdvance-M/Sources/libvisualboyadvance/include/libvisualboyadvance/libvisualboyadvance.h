// libvisualboyadvance exposes no Swift-visible API.
//
// The VBA-M 2.x core headers are C++ (std::unique_ptr in core/base/system.h,
// a `log(const char*, ...)` that overloads Darwin's log()), so they are kept
// out of the module. PVVisualBoyAdvanceBridge includes them directly through
// its header search path (visualboyadvance-m/src).
#pragma once
