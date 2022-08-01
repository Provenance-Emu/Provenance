MODULE := src/unix/r77

MODULE_OBJS := \
	src/unix/r77/OSystemR77.o \
	src/unix/r77/SettingsR77.o

MODULE_DIRS += \
	src/unix/r77

# Include common rules
include $(srcdir)/common.rules
