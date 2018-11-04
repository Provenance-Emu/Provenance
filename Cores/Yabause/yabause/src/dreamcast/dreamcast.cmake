# CMake toolchain file for building Yabause on the Dreamcast
set(CMAKE_SYSTEM_NAME Generic)

# Use the gnu_wrappers for the various GNU utilities
set(CMAKE_C_COMPILER kos-cc)
set(CMAKE_CXX_COMPILER kos-c++)
set(CMAKE_ASM_COMPILER kos-as)

# KOS Sets this nicely for us.
set(CMAKE_FIND_ROOT_PATH $ENV{KOS_CC_BASE})

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# Set some stuff so that it doesn't complain about the lack of a normal looking
# pthreads flag/library for the compiler.
set(THREADS_HAVE_PTHREAD_ARG 1)
set(CMAKE_HAVE_THREADS_LIBRARY 1)

# Set a flag so we know we're trying to compile for Dreamcast
set(dreamcast 1)
