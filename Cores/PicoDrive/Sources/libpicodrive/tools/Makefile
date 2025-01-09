CFLAGS = -Wall -ggdb

TARGETS = amalgamate textfilter mkoffsets
OBJS = $(addsuffix .o,$(TARGETS))

all: $(TARGETS)

clean:
	$(RM) $(TARGETS) $(OBJS)

mkoffsets: CFLAGS += -m32 -I..

.PHONY: clean all
