CFLAGS += -Wall -ggdb
ifdef CONFIG_FILE
CFLAGS += -DCONFIG_FILE="\"$(CONFIG_FILE)\""
endif
CXXFLAGS += $(CFLAGS)

OBJS = Main.o Ea.o OpAny.o OpArith.o OpBranch.o OpLogic.o OpMove.o Disa/Disa.o

all: Cyclone.s

Cyclone.s: cyclone_gen
	./$<

cyclone_gen: $(OBJS)
	$(CXX) -o $@ $^ $(LDFLAGS)

clean:
	$(RM) $(OBJS) cyclone_gen Cyclone.s

$(OBJS): app.h config.h Cyclone.h
ifdef CONFIG_FILE
$(OBJS): $(CONFIG_FILE)
endif
