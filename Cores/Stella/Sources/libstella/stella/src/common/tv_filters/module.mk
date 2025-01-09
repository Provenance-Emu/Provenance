MODULE := src/common/tv_filters

MODULE_OBJS := \
	src/common/tv_filters/NTSCFilter.o \
	src/common/tv_filters/AtariNTSC.o

MODULE_DIRS += \
	src/common/tv_filters

# Include common rules
include $(srcdir)/common.rules
