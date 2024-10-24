MODULE := src/common

MODULE_OBJS := \
	src/common/AudioQueue.o \
	src/common/AudioSettings.o \
	src/common/Base.o \
        src/common/Bezel.o \
	src/common/DevSettingsHandler.o \
	src/common/EventHandlerSDL2.o \
	src/common/FBBackendSDL2.o \
	src/common/FBSurfaceSDL2.o \
	src/common/FpsMeter.o \
	src/common/FSNodeZIP.o \
	src/common/HighScoresManager.o \
	src/common/JoyMap.o \
	src/common/JPGLibrary.o \
	src/common/KeyMap.o \
	src/common/Logger.o \
	src/common/main.o \
	src/common/MouseControl.o \
	src/common/PaletteHandler.o \
	src/common/PhosphorHandler.o \
	src/common/PhysicalJoystick.o \
	src/common/PJoystickHandler.o \
	src/common/PKeyboardHandler.o \
	src/common/PNGLibrary.o \
	src/common/RewindManager.o \
	src/common/SoundSDL2.o \
	src/common/StaggeredLogger.o \
	src/common/StateManager.o \
	src/common/ThreadDebugging.o \
	src/common/TimerManager.o \
	src/common/VideoModeHandler.o \
	src/common/ZipHandler.o \
	src/common/sdl_blitter/BilinearBlitter.o \
	src/common/sdl_blitter/QisBlitter.o \
	src/common/sdl_blitter/BlitterFactory.o \
	src/common/repository/KeyValueRepositoryPropertyFile.o \
	src/common/repository/KeyValueRepositoryJsonFile.o \
	src/common/repository/KeyValueRepositoryConfigfile.o \
	src/common/repository/CompositeKVRJsonAdapter.o \
	src/common/repository/CompositeKeyValueRepository.o

MODULE_DIRS += \
	src/common

# Include common rules
include $(srcdir)/common.rules
