CC = gcc
LD = gcc
STRIP = strip
BUILD = Build
TARGET = bin2c

CFLAGS = -O -Wall
SLFLAGS = -s -O

OBJS = bin2c.o

BUILDOBJS = $(addprefix $(BUILD)/, $(notdir $(OBJS)))

.PHONY: all clean

all: $(BUILD) $(TARGET)

$(BUILD):
	@[ -d @ ] || mkdir -p $@

$(BUILD)/%.o: %.c
	$(CC) $(CFLAGS) -o $@ -c $<

$(TARGET): $(BUILDOBJS)
	$(LD) $(SLFLAGS) -o $(TARGET) $(BUILDOBJS)

clean:
	-rm -f $(BUILDOBJS) $(TARGET) $(TARGET).exe
	-rmdir --ignore-fail-on-non-empty $(BUILD)
