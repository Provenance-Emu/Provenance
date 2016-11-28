all : m68kops.c

m68kops.c : m68kmake
	./$<

m68kmake : m68kmake.c m68k_in.c
	$(CC) -o $@ $<


clean:
	$(RM) m68kops.c m68kops.h m68kmake *.o

