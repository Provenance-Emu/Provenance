mednafen_SOURCES += net/Net.cpp

if HAVE_POSIX_SOCKETS
mednafen_SOURCES += net/Net_POSIX.cpp
endif

if WIN32
mednafen_SOURCES += net/Net_WS2.cpp
endif

