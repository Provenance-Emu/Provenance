if WIN32
mednafen_SOURCES += time/Time_Win32.cpp
else
mednafen_SOURCES += time/Time_POSIX.cpp
endif

