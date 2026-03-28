// DolphinCxxCompat.h
// Force-included via OTHER_CPLUSPLUSFLAGS to fix C++23 + Clang CXX modules.
//
// With -fcxx-modules, C++ stdlib headers are treated as modules with strict
// visibility — transitive includes no longer expose symbols. Dolphin's headers
// assume transitive availability (e.g. <chrono> pulling in <ratio>).
// Pre-including these headers makes their symbols visible to all TUs.

#pragma once

#ifdef __cplusplus
#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <ratio>
#include <string>
#include <thread>
#include <type_traits>
#include <utility>
#include <vector>
#endif
