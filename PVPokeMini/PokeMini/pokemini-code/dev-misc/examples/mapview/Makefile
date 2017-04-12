.PHONY: all media run flash clean

PMDEV_DIR = ../../..

IMAGE = pokemap.pmimage
MUSIC = 
DEPS = 
SRC = mapview.asm
OUT = mapview.min

IMAGE_OUT = $(IMAGE:.pmimage=.bin)
MUSIC_OUT = $(MUSIC:.pmmusic=.asm)

all: $(OUT)
media: $(IMAGE_OUT) $(MUSIC_OUT)

%.bin: %.pmimage
	$(PMDEV_DIR)/pokemini_imgconv -q -c $< -o $@

%.asm: %.pmmusic
	$(PMDEV_DIR)/pokemini_musicconv -q -i $< -o $@

$(OUT): $(SRC) $(DEPS) $(IMAGE_OUT) $(MUSIC_OUT)
	$(PMDEV_DIR)/pmas $< $@

run: $(OUT)
	$(PMDEV_DIR)/PokeMiniD $< &

flash: $(OUT)
	$(PMDEV_DIR)/PokeFlash -f $<

clean:
	$(RM) $(OUT) $(IMAGE_OUT) $(MUSIC_OUT)
