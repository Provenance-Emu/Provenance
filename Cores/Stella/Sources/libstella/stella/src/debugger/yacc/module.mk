MODULE := src/debugger/yacc

MODULE_OBJS := \
	src/debugger/yacc/YaccParser.o

MODULE_DIRS += \
	src/debugger/yacc

# Include common rules
include $(srcdir)/common.rules
