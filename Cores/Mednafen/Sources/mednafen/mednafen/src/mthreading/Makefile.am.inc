if WIN32
mednafen_SOURCES += mthreading/MThreading_Win32.cpp
else
mednafen_SOURCES += mthreading/MThreading_POSIX.cpp
endif

