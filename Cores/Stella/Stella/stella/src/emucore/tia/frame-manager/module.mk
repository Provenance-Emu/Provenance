MODULE := src/emucore/tia/frame-manager

MODULE_OBJS := \
	src/emucore/tia/frame-manager/FrameManager.o \
	src/emucore/tia/frame-manager/AbstractFrameManager.o \
	src/emucore/tia/frame-manager/FrameLayoutDetector.o \
	src/emucore/tia/frame-manager/JitterEmulation.o

MODULE_DIRS += \
	src/emucore/tia/frame-manager

# Include common rules
include $(srcdir)/common.rules
