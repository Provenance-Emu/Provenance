MODULE := src/common/audio

MODULE_OBJS := \
	src/common/audio/SimpleResampler.o \
	src/common/audio/ConvolutionBuffer.o \
	src/common/audio/LanczosResampler.o \
	src/common/audio/HighPass.o

MODULE_DIRS += \
	src/emucore/tia

# Include common rules
include $(srcdir)/common.rules
