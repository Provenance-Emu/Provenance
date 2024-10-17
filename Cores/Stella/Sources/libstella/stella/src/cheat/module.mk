MODULE := src/cheat

MODULE_OBJS := \
	src/cheat/CheatCodeDialog.o \
	src/cheat/CheatManager.o \
	src/cheat/CheetahCheat.o \
	src/cheat/BankRomCheat.o \
	src/cheat/RamCheat.o

MODULE_DIRS += \
	src/cheat

# Include common rules 
include $(srcdir)/common.rules
