// SPDX-FileCopyrightText: Copyright (c) 2023 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#if defined(__APPLE__)
#    define OAKNUT_CPU_FEATURE_DETECTION 1
#    define OAKNUT_SUPPORTS_READING_ID_REGISTERS 0
#    include "oaknut/feature_detection/feature_detection_apple.hpp"
#elif defined(__FreeBSD__)
#    define OAKNUT_CPU_FEATURE_DETECTION 1
#    define OAKNUT_SUPPORTS_READING_ID_REGISTERS 1
#    include "oaknut/feature_detection/feature_detection_freebsd.hpp"
#elif defined(__linux__)
#    define OAKNUT_CPU_FEATURE_DETECTION 1
#    define OAKNUT_SUPPORTS_READING_ID_REGISTERS 1
#    include "oaknut/feature_detection/feature_detection_linux.hpp"
#elif defined(__NetBSD__)
#    define OAKNUT_CPU_FEATURE_DETECTION 1
#    define OAKNUT_SUPPORTS_READING_ID_REGISTERS 2
#    include "oaknut/feature_detection/feature_detection_netbsd.hpp"
#elif defined(__OpenBSD__)
#    define OAKNUT_CPU_FEATURE_DETECTION 1
#    define OAKNUT_SUPPORTS_READING_ID_REGISTERS 1
#    include "oaknut/feature_detection/feature_detection_openbsd.hpp"
#elif defined(_WIN32)
#    define OAKNUT_CPU_FEATURE_DETECTION 1
#    define OAKNUT_SUPPORTS_READING_ID_REGISTERS 2
#    include "oaknut/feature_detection/feature_detection_w32.hpp"
#else
#    define OAKNUT_CPU_FEATURE_DETECTION 0
#    define OAKNUT_SUPPORTS_READING_ID_REGISTERS 0
#    warning "Unsupported operating system for CPU feature detection"
#    include "oaknut/feature_detection/feature_detection_generic.hpp"
#endif
