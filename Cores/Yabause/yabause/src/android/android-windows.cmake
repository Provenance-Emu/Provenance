SET(CMAKE_SYSTEM_NAME Linux)
SET(CMAKE_SYSTEM_VERSION 1)

SET(CMAKE_C_COMPILER   "C:/android-ndk-r8e/toolchains/arm-linux-androideabi-4.6/prebuilt/windows/bin/arm-linux-androideabi-gcc.exe")
SET(CMAKE_CXX_COMPILER "C:/android-ndk-r8e/toolchains/arm-linux-androideabi-4.6/prebuilt/windows/bin/arm-linux-androideabi-g++.exe")
SET(CMAKE_ASM-ATT_COMPILER "C:/android-ndk-r8e/toolchains/arm-linux-androideabi-4.6/prebuilt/windows/bin/arm-linux-androideabi-as.exe")

SET(CMAKE_FIND_ROOT_PATH "C:/android-ndk-r8e/platforms/android-8/arch-arm/usr")

set(CMAKE_C_FLAGS "--sysroot=C:/android-ndk-r8e/platforms/android-8/arch-arm" CACHE STRING "GCC flags" FORCE)
set(CMAKE_CXX_FLAGS "--sysroot=C:/android-ndk-r8e/platforms/android-8/arch-arm" CACHE STRING "G++ flags" FORCE)

SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

SET(ANDROID ON)
