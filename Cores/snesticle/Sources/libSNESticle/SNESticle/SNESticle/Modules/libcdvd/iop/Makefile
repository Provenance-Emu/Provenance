IOP_LDFLAGS += -m mipsirx 

IOP_BIN = ../lib/cdvd.irx

IOP_OBJS = cdvd_iop.o iop_cdvdman.o


all: $(IOP_BIN)

clean:
	rm -f $(IOP_BIN) $(IOP_OBJS)

include $(PS2LIB)/Makefile.pref
include $(PS2LIB)/Makefile.iopglobal
