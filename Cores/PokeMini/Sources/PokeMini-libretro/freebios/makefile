# FreeBIOS Makefile

POKEROOT = ../
PMAS = $(POKEROOT)tools/pmas/pmas
BIN2C = $(POKEROOT)tools/bin2c/bin2c

.PHONY: all clean

all: freebios.c

freebios.c : freebios.asm
	$(PMAS) freebios.asm freebios.min
	$(BIN2C) freebios.min freebios.c FreeBIOS

clean:
	-rm -f freebios.min freebios.c
