cmake project files located inside src folder. To build the project with cmake, run

cmake [-DCMAKE_BUILD_TYPE=Debug] [-DVEC4_OPT=On] [-DCRC_OPT=On] [-DX86_OPT=On] [-DNEON_OPT=On] [DCRC_ARMV8=On] [-DNOHQ=On] [-DUSE_SYSTEM_LIBS=On] -DMUPENPLUSAPI=On ../../src/

-DCMAKE_BUILD_TYPE=Debug - optional parameter, if you want debug build. Default buid type is Release
-DVEC4_OPT=On  - optional parameter. set it if you want to enable additional VEC4 optimization (can cause additional bugs).
-DCRC_OPT=On - optional parameter. set it to use xxHash to calculate texture CRC.
-DX86_OPT=On - optional parameter. set it if you want to enable additional X86 ASM optimization (can cause additional bugs).
-DNEON_OPT=On - optional parameter. set it if you want to enable additional ARM NEON optimization (can cause additional bugs).
-DCRC_ARMV8=On - optional parameter. set it if you want to enable armv8 hardware CRC.
-DNOHQ=On - optional parameter. set to build without realtime texture enhancer library (GLideNHQ).
-DUSE_SYSTEM_LIBS=On - optional parameter. set to use system provided libraries for libpng and zlib.
-DMUPENPLUSAPI=On - required parameter. currently cmake build works only for mupen64plus version of the plugin.
-DODROID=On - set if you need to build on an Odroid board.
-DVERO4K=On - set if you need to build on the OSMC Vero4k.
