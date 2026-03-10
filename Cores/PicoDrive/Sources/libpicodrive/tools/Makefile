TARGETS = amalgamate textfilter make_carthw_c
HOSTCC ?= cc

all:
	if [ -f "offsets/$(XPLATFORM)-offsets.h" ]; then \
		ln -sf "../tools/offsets/$(XPLATFORM)-offsets.h" ../pico/pico_int_offs.h; \
	else \
		CC="$(XCC)" CFLAGS="$(XCFLAGS)" sh ./mkoffsets.sh ../pico; \
	fi

$(TARGETS): $(addsuffix .c,$(TARGETS))
	$(HOSTCC) -o $@ -O $@.c

clean:
	$(RM) $(TARGETS) $(OBJS)

.PHONY: clean all
