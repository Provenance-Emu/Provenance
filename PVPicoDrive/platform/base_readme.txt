#
PicoDrive 1.xx

About
-----
#include "../README"

How to make it run
------------------

#ifdef GP2X
Extract all files to some directory on your SD and run PicoDrive.gpe from your
GP2X/Wiz/Caanoo menu. The same .gpe supports GP2X F100/F200, Wiz and Caanoo,
there is no need to use separate versions.
Then load a ROM and enjoy! ROMs can be in .smd or .bin format and can be zipped.
Sega/Mega CD images can be in ISO/CSO+MP3/WAV or CUE+BIN formats (read below
for more details).
#endif
#ifdef GIZ
First make sure you have homebrew-enabled Service Pack installed. Then copy
PicoDrive.exe and KGSDK.dll to any place in your filesystem (both files must
be in the same directory) and run PicoDrive.exe using the launcher of your choice
(some of them might require renaming PicoDrive.exe to Autorun.exe, placing it in
the root of SD, etc). Then load a ROM and enjoy! ROMs can be placed anywhere, can
be in .smd or .bin format and can be zipped (one ROM per zip).
#endif
#ifdef PSP
If you are running a custom firmware, just copy the whole PicoDrive directory to
/PSP/GAME or /PSP/GAMEXXX directory in your memory stick (it shouldn't matter
which one GAME* directory to use).

If you are on 1.5, there is a separate KXploited version for it.
#endif
#ifdef PANDORA
Just copy the .pnd to <sd card>/pandora/menu or <sd card>/pandora/desktop.
#endif

This emulator has lots of options with various tweaks (for improved speed mostly),
but it should have best compatibility in it's default config. If suddenly you
start getting glitches or change something and forget what, use "Restore defaults"
option.


How to run Sega/Mega CD games
-----------------------------

To play any CD game, you need BIOS files. These files must be copied to
#ifdef PANDORA
<sd card>/pandora/appdata/picodrive/ directory
(if you run PicoDrive once it will create that directory for you).
#else
the same directory as PicoDrive files.
#endif
Files can be named as follows:

US: us_scd1_9210.bin us_scd2_9306.bin SegaCDBIOS9303.bin
EU: eu_mcd1_9210.bin eu_mcd2_9303.bin eu_mcd2_9306.bin
JP: jp_mcd1_9112.bin jp_mcd1_9111.bin
these files can also be zipped.

The game must be dumped to CUE+BIN or CUE+ISO format.
ISO/CSO+MP3/WAV is also supported, but may cause problems.
When using CUE/BIN, you must load .cue file from the menu, or else
the emu will not find audio tracks.


Other important stuff
---------------------

* Sega/Mega CD: If the background music is missing, the CD image format may be
  wrong. Currently .cue/bin is recommended. Be aware that there are lots of bad
  dumps on the web, and some use mp3 format for audio, which often causes
  problems (see below).
* While iso/mp3 format is supported, it's not recommended to use.
  Some of many problems with mp3 are listed below:
  * MP3s may be named incorrectly and will not play.
  * The game music may play too fast/too slow/out of sync, which means they
    are encoded incorrectly. PicoDrive is not a mp3 player, so all mp3s MUST
    be encoded at 44.1kHz stereo.
* Sega/Mega CD: If your games hang at the BIOS screen (with planets shown),
  you may be using a bad BIOS dump. Try another from a different source,
  like dumping it from your own console.
#ifdef GP2X
* What using mp3s, use lower bitrate for better performance (96 or 128kbps
  CBRs recommended).
* GP2X F100/F200: When you use both GP2X CPUs, keep in mind that you can't
  overclock as high as when using ARM920 only. For example my GP2X when run
  singlecore can reach 280MHz, but with both cores it's about 250MHz. When
  overclocked too much, it may start hanging and producing random noise, or
  causing ARM940 crashes ("940 crashed" message displayed).
* GP2X F100/F200: Due to internal implementation mp3s must not be larger that
  12MB (12582912 bytes). Larger mp3s will not be fully loaded.
#endif


Configuration
-------------

@@0. "Save slot"
This is a slot number to use for savestates, when done by a button press outside
menu. This can also be configured to be changed with a button
(see "key configuration").

@@0. "Frameskip"
How many frames to skip rendering before displaying another.
"Auto" is recommended.

@@0. "Region"
This option lets you force the game to think it is running on machine from the
specified region, or just to set autodetection order. Also affects Sega/Mega CD.

@@0. "Show FPS"
Self-explanatory. Format is XX/YY, where XX is the number of rendered frames and
YY is the number of emulated frames per second.

@@0. "Enable sound"
Does what it says. You must enable at least YM2612 or SN76496 (in advanced options,
see below) for this to make sense (already done by default).

@@0. "Sound Quality"
#ifdef PSP
Sound sample rate, affects sound quality and emulation performance.
22050Hz setting is the recommended one.
#else
Sound sample rate and stereo mode. Mono is not available in Sega/Mega CD mode.
#endif

@@0. "Confirm savestate"
Allows to enable confirmation on savestate saving (to prevent savestate overwrites),
on loading (to prevent destroying current game progress), and on both or none, when
using shortcut buttons (not menu) for saving/loading.

@@0. "[Display options]"
Enters Display options menu (see below).

@@0. "[Sega/Mega CD options]"
Enters Sega/Mega CD options menu (see below).

@@0. "[32X options]"
Enters 32X options menu (see below).

@@0. "[Advanced options]"
Enters advanced options menu (see below).

@@0. "Save cfg as default"
If you save your config here it will be loaded on next ROM load, but only if there
is no game specific config saved (which will be loaded in that case).
You can press left/right to switch to a different config profile.

@@0. "Save cfg for current game only"
Whenever you load current ROM again these settings will be loaded.

@@0. "Restore defaults"
Restores all options (except controls) to defaults.


Display options
---------------

#ifndef PANDORA
@@1. "Renderer"
#ifdef GP2X
8bit fast:
This enables alternative heavily optimized tile-based renderer, which renders
pixels not line-by-line (this is what accurate renderers do), but in 8x8 tiles,
which is much faster. But because of the way it works it can't render any
mid-frame image changes (raster effects), so it is useful only with some games.

Other two are accurate line-based renderers. The 8bit is faster but does not
run well with some games like Street Racer.

#endif
#ifdef GIZ
This option allows to switch between 16bit and 8bit renderers. The 8bit one is
a bit faster for some games, but not much, because colors still need to be
converted to 16bit, as this is what Gizmondo requires. It also introduces
graphics problems for some games, so it's best to use 16bit one.

#endif
#ifdef PSP
This option allows to switch between fast and accurate renderers. The fast one
is much faster, because it draws the whole frame at a time, instead of doing it
line by line, like the accurate one does. But because of the way it works it
can't render any mid-frame image changes (raster effects), so it is useful only
for some games.

#endif
#endif
#ifdef GP2X
@@1. "Tearing Fix"
Wiz only: works around the tearing problem by using portrait mode. Causes ~5-10%
performance hit, but eliminates the tearing effect.

@@1. "Gamma correction"
F100/F200 only: Alters image gamma through GP2X hardware. Larger values make
image to look brighter, lower - darker (default is 1.0).

@@1. "Vsync"
This one adjusts the LCD refresh rate to better match game's refresh rate and
starts synchronizing rendering with it. Should make scrolling smoother and
eliminate tearing on F100/F200.
#endif
#ifdef GIZ
@@1. "Scanline mode"
This option was designed to work around slow framebuffer access (the Gizmondo's
main bottleneck) by drawing every other line (even numbered lines only).
This improves performance greatly, but looses detail.

@@1. "Scale low res mode"
The Genesis/Megadrive had several graphics modes, some of which were only 256
pixels wide. This option scales their width to 320 by using simple
pixel averaging scaling. Works only when 16bit renderer is enabled.

@@1. "Double buffering"
Draws the display to offscreen buffer, and flips it with visible one when done.
Unfortunately this causes serious tearing, unless v-sync is used (next option).

@@1. "Wait for V-sync"
Waits for vertical sync before drawing (or flipping buffers, if previous option
is enabled). Emulation is stopped while waiting, so this causes large performance
hit.
#endif
#ifdef PSP
@@1. "Scale factor"
This allows to resize the displayed image by using the PSP's hardware. The number is
used to multiply width and height of the game image to get the size of image to be
displayed. If you just want to make it fullscreen, just use "Set to fullscreen"
setting below.

@@1. "Hor. scale (for low res. games)"
This one works similarly as the previous setting, but can be used to apply additional
scaling horizontally, and is used for games which use lower (256 pixel wide) Gen/MD
resolution.

@@1. "Hor. scale (for hi res. games)"
Same as above, only for higher (320 pixel wide) resolution using games.

@@1. "Bilinear filtering"
If this is enabled, PSP hardware will apply bilinear filtering on the resulting image,
making it smoother, but blurry.

@@1. "Gamma adjustment"
Color gamma can be adjusted with this.

@@1. "Black level"
This can be used to reduce unwanted "ghosting" effect for dark games, by making
black pixels brighter. Use in conjunction with "gamma adjustment" for more effect.

@@1. "Wait for v-sync"
Wait for the screen to finish updating before switching to next frame, to avoid tearing.
There are 3 options:
* never: don't wait for vsync.
* sometimes: wait only if emulator is running fast enough.
* always: always wait (causes emulation slowdown).

@@1. "Set to unscaled centered"
Adjust the resizing options to set game image to it's original size.

@@1. "Set to 4:3 scaled"
Scale the image up, but keep 4:3 aspect, by adding black borders.

@@1. "Set to fullscreen"
Adjust the resizing options to make the game image fullscreen.
#endif
#ifdef PANDORA
Allows to set up scaling, filtering and vertical sync.
#endif


Sega/Mega CD options 
--------------------

@@2. "CD LEDs"
The Sega/Mega CD unit had two blinking LEDs (red and green) on it. This option
will display them on top-left corner of the screen.

@@2. "CDDA audio"
This option enables CD audio playback.

@@2. "PCM audio"
This enables 8 channel PCM sound source. It is required for some games to run,
because they monitor state of this audio chip.

@@2. "Save RAM cart"
Here you can enable 64K RAM cart. Format it in BIOS if you do.

@@2. "Scale/Rot. fx"
The Sega/Mega CD had scaling/rotation chip, which allows effects similar to
"Mode 7" effects in SNES. On slow systems like GP2X, disabling may improve
performance but cause graphical glitches.


32X options
-----------

@@3. "32X enabled"
Enables emulation of addon. Option only takes effect when ROM is reloaded.

#ifdef GP2X
@@3. "32X renderer"
This currently only affects how the Genesis/MD layers are rendered, which is
same as "Renderer" in display options.

#endif
@@3. "PWM sound"
Emulates PWM sound portion of 32X hardware. Disabling this may greatly improve
performance for games that dedicate one of SD2s for sound, but will cause
missing sound effects and instruments.

@@3. "Master SH2 cycles" / "Slave SH2 cycles"
This allows underclocking the 32X CPUs for better emulation performance. The
number has the same meaning as cycles in DOSBox, which is cycles per millisecond.
Underclocking too much may cause various in-game glitches.


Advanced configuration
----------------------

@@4. "Use SRAM/BRAM savestates"
This will automatically read/write SRAM (or BRAM for Sega/Mega CD) savestates for
games which are using them. SRAM is saved whenever you enter the menu or exit the
emulator.

@@4. "Disable sprite limit"
The MegaDrive/Genesis had a limit on how many sprites (usually smaller moving
objects) can be displayed on single line. This option allows to disable that
limit. Note that some games used this to hide unwanted things, so it is not
always good to enable this option.

@@4. "Emulate Z80"
Enables emulation of Z80 chip, which was mostly used to drive the other sound chips.
Some games do complex sync with it, so you must enable it even if you don't use
sound to be able to play them.

@@4. "Emulate YM2612 (FM)"
This enables emulation of six-channel FM sound synthesizer chip, which was used to
produce sound effects and music.

@@4. "Emulate SN76496 (PSG)"
This enables emulation of PSG (programmable sound generation) sound chip for
additional effects.

Note: if you change sound settings AFTER loading a ROM, you may need to reset
game to get sound. This is because most games initialize sound chips on
startup, and this data is lost when sound chips are being enabled/disabled.

@@4. "gzip savestates"
This will always apply gzip compression on your savestates, allowing you to
save some space and load/save time.

@@4. "Don't save last used ROM"
This will disable writing last used ROM to config on exit (what might cause SD
card corruption according to DaveC).

@@4. "Disable idle loop patching"
Idle loop patching is used to improve performance, but may cause compatibility
problems in some rare cases. Try disabling this if your game has problems.

@@4. "Disable frame limiter"
This allows games to run faster then 50/60fps, useful for benchmarking.

#ifdef GP2X
@@4. "Use ARM940 core for sound"
F100/F200: This option causes PicoDrive to use ARM940T core (GP2X's second CPU)
for sound (i.e. to generate YM2612 samples) to improve performance noticeably.
It also decodes MP3s in Sega/Mega CD mode.

#endif
@@4. "Enable dynarecs"
This enables dynamic recompilation for SH2 and SVP CPU code,
what improves emulation performance greatly.


Key configuration
-----------------

Select "Configure controls" from the main menu. Then select "Player 1" and you will
see two columns. The left column lists names of Genesis/MD controller buttons, and
the right column your handheld ones, which are assigned.

There is also option to enable 6 button pad (will allow you to configure XYZ
buttons), and an option to set turbo rate (in Hz) for turbo buttons.


Cheat support
-------------

To use GG/patch codes, you must type them into your favorite text editor, one
per line. Comments may follow code after a whitespace. Only GameGenie and
Genecyst patch formats are supported.
Examples:

Genecyst patch (this example is for Sonic):

00334A:0005 Start with five lives
012D24:0001 Keep invincibility until end of stage
009C76:5478 each ring worth 2
009C76:5678 each ring worth 3
...

Game Genie patch (for Sonic 2):

ACLA-ATD4 Hidden palace instead of death egg in level select
...

Both GG and patch codes can be mixed in one file.

When the file is ready, name it just like your ROM file, but with additional
.pat extension, making sure that case matches.

Examples:

ROM: Sonic.zip
PATCH FILE: Sonic.zip.pat

ROM: Sonic 2.bin
PATCH FILE: Sonic 2.bin.pat

Put the file into your ROMs directory. Then load the .pat file as you would
a ROM. Then Cheat Menu Option should appear in main menu.


What is emulated?
-----------------

Genesis/MegaDrive:
#ifdef PSP
main 68k @ 7.6MHz: yes, FAME/C core
z80 @ 3.6MHz: yes, CZ80 core
#else
main 68k @ 7.6MHz: yes, Cyclone core
z80 @ 3.6MHz: yes, DrZ80 core
#endif
VDP: yes, except some quirks and modes not used by games
YM2612 FM: yes, optimized MAME core
SN76489 PSG: yes, MAME core
SVP chip: yes! This is first emu to ever do this.
Some in-cart mappers are also supported.

Sega/Mega CD:
#ifdef PSP
another 68k @ 12.5MHz: yes, FAME/C too
#else
another 68k @ 12.5MHz: yes, Cyclone too
#endif
gfx scaling/rotation chip (custom ASIC): yes
PCM sound source: yes
CD-ROM controller: yes (mostly)
bram (internal backup RAM): yes

32X:
2x SH2 @ 23MHz: yes, custom recompiler
Super VDP: yes
PWM: yes


Problems / limitations
----------------------

#ifdef PSP
* SVP emulation is terribly slow.
#endif
* Various VDP modes and quirks (window bug, scroll size 2, etc.) are not
  emulated, as very few games use this (if any at all).
* The emulator is not 100% accurate, so some things may not work as expected.
* The FM sound core doesn't support all features and has some accuracy issues.


Changelog
-------

#include "../ChangeLog"


Credits
-------

This emulator is made of the code from following people/projects:

#include "../AUTHORS"


License
-------

This program and it's code is released under the terms of MAME license:
#include "../COPYING"

SEGA/Genesis/MegaDrive/SEGA-CD/Mega-CD/32X are trademarks of
Sega Enterprises Ltd.

