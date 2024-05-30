MODULE := src/debugger

MODULE_OBJS := \
        src/debugger/BreakpointMap.o \
        src/debugger/Debugger.o \
        src/debugger/DebuggerParser.o \
        src/debugger/CartDebug.o \
        src/debugger/CpuDebug.o \
        src/debugger/DiStella.o \
        src/debugger/RiotDebug.o \
        src/debugger/TIADebug.o \
        src/debugger/TimerMap.o

MODULE_DIRS += \
        src/debugger

# Include common rules
include $(srcdir)/common.rules
