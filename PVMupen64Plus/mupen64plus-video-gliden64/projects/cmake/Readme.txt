cmake project files located inside src folder. To build the project with cmake, run

cmake [-DCMAKE_BUILD_TYPE=Debug] [-DVEC4_OPT=On] [-DCRC_OPT=On] [-DNEON_OPT=On] [-DX86_OPT=On] [-DNOHQ=On] [-DUSE_UNIFORMBLOCK=On] -DMUPENPLUSAPI=On ../../src/

-DCMAKE_BUILD_TYPE=Debug - optional parameter, if you want debug build. Default buid type is Release
-DVEC4_OPT=On  - optional parameter. set it if you want to enable additional VEC4 optimization (can cause additional bugs).
-DCRC_ARMV8=On  - optional parameter. set it if you want to enable armv8 hardware CRC.
-DCRC_OPT=On - optional parameter. set it to use xxHash to calculate texture CRC.
-DNEON_OPT=On - optional parameter. set it if you want to enable additional ARM NEON optimization (can cause additional bugs).
-DX86_OPT=On - optional parameter. set it if you want to enable additional X86 ASM optimization (can cause additional bugs).
-DNOHQ=On - build without realtime texture enhancer library (GLideNHQ).
-DMUPENPLUSAPI=On - currently cmake build works only for mupen64plus version of the plugin.
-DUSE_SYSTEM_LIBS=On - set to use system provided libraries for libpng and zlib.
