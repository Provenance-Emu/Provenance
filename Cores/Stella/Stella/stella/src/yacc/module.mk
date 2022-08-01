MODULE := src/yacc

MODULE_OBJS := \
	src/yacc/YaccParser.o

MODULE_DIRS += \
	src/yacc

# Include common rules 
include $(srcdir)/common.rules
