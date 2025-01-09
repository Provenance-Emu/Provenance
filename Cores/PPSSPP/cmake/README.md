Steps Needed to Customize Core Lib XCode Project (PPSSPP.xcodeproj):
1. Remove script from ZERO_CHECK / GitVersion build phase
2. Remove mm files except iCoreAudio.mm, AppleBatteryClient.m from libnative
3. Remove MemArenaDarwin.cpp, and other MemArena*.cpp (e.g. MemArenaAndroid.cpp) from libCommon 

* Change Build Directory to $(SRCROOT)/lib/ppssspp
* Change Name of libraries (e.g. xxHash -> xxHashPPSSPP)
