MODULE := src/unix

MODULE_OBJS := \
	src/unix/FSNodePOSIX.o \
	src/unix/OSystemUNIX.o \
	src/unix/SerialPortUNIX.o

MODULE_DIRS += \
	src/unix

# Include common rules
include $(srcdir)/common.rules
