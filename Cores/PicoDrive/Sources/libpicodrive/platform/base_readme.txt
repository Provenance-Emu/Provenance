About PicoDrive
---------------

#include "../README.md"


How to make it run
------------------

#ifdef GENERIC
Extract the zip file into some directory and run PicoDrive from there.
#endif
#ifdef GP2X
Extract all files to some directory on your SD and run PicoDrive.gpe from your
GP2X/Wiz/Caanoo menu. The same .gpe supports GP2X F100/F200, Wiz and Caanoo,
there is no need to use separate versions.
#endif
#ifdef GIZ
First make sure you have homebrew-enabled Service Pack installed. Then copy
PicoDrive.exe and KGSDK.dll to any place in your filesystem (both files must
be in the same directory) and run PicoDrive.exe using the launcher of your choice
(some of them might require renaming PicoDrive.exe to Autorun.exe, placing it in
the root of SD, etc).
#endif
#ifdef PSP
If you are running a custom firmware, just copy the whole PicoDrive directory to
/PSP/GAME or /PSP/GAMEXXX directory in your memory stick (it shouldn't matter
which one GAME* directory to use).
#endif
#ifdef PANDORA
Just copy the .pnd to <sd card>/pandora/menu or <sd card>/pandora/desktop.
#endif

Then load a ROM and enjoy! Cartridge ROMs can be in various common formats and
can be zipped, one ROM file per zip. Certain extensions are used to detect the
console the ROM is for (.sg, .sc, .sms, .gg, .smd, .md, .gen, .32x, .pco).
For MSU or MD+ games, load the .cue file and make sure the cartridge ROM has the
same name and is in the same directory. MD+ use extensions in the .cue file,
hence don't try to convert it to any other format.
Sega/Mega CD images can be in CHD, CUE+BIN/ISO or ISO/CSO+MP3/WAV format (read
below for more details).

This emulator has lots of options with various tweaks (for improved speed mostly),
but it should have best compatibility in it's default config. If suddenly you
start getting glitches or change something and forget what, use "Restore defaults"
option.


How to run Sega/Mega CD games
-----------------------------

To play any non-MSU/MD+ CD game you need BIOS files. These must be copied to
#ifdef PANDORA
<sd card>/pandora/appdata/picodrive/ directory
(if you run PicoDrive once it will create that directory for you).
#else
#ifdef GENERIC
the .picodrive directory in your home directory.
#else
the same directory as PicoDrive files.
#endif
#endif
Files must be named as follows:

US: us_scd1_9210.bin, us_scd2_9306.bin, SegaCDBIOS9303.bin
EU: eu_mcd1_9210.bin, eu_mcd2_9303.bin, eu_mcd2_9306.bin
JP: jp_mcd1_9112.bin, jp_mcd1_9111.bin
these files can also be zipped.

The game must be dumped to CHD, CUE+BIN or CUE+ISO format.
ISO/CSO+MP3/WAV is also supported, but may cause problems.
When using CUE/BIN, you must load .cue file from the menu, or else the emu will
not find audio tracks.


How to run Sega Pico games
--------------------------

The Pico was special in that it had a large touchpad with an associated pen, and
so-called storyware, a combination of a cartridge with a book with up to 6 pages
on which the pen could also be used.

Most storywares used the touchpad with the pen as a pointer device, showing a
pointer icon on the screen when the pen was on the touchpad which could be moved
around. The pen has a dedicated button which was often used to select something
under the pointer icon, much like a mouse button.
However, a few games also had an overlay for the touchpad.

PicoDrive supports displaying both the storyware pages as well as a pad overlay.
They must be in png format and named like the storyware ROM without the
extension, plus "_<n>.png" for the storyware page <n>, and "_pad.png" for a pad
overlay. Storyware page images should have an aspect ration of 2:1, pad images
should have 4:3. All images can have arbitrary resolution and are automatically
scaled to fit the screen.

There are 2 menu actions for switching to pages or pad which will automatically
display the images if they are available. To allow for proper pen positioning
there is also an action for having the pen on the page/touchpad or not. Pen
positioning is done through the D-pad if the screen has been switched to either
pages or pad.


How to load SC-3000 tapes
-------------------------

The SC-3000 microcomputer has a connector for connecting a cassette tape drive
to it. PicoDrive supports using tape recordings in WAV or bitstream format.
Run one of the BASIC cartridges, then load the tape with the "Load tape" menu.
Entering the LOAD command using the keyboard emulation automatically starts
the emulated tape drive. You will get a confirmation after the tape has been
loaded.

The emulated tape drive has an automatic start/stop feature. Tapes requiring
several load operations don't need any additional handling.


How to use keyboard input
-------------------------

Both the SC-3000 and the Sega Pico support keyboard input. To activate keyboard
input in PicoDrive, press the "Switch keyboard" emulator hotkey while running
a cartridge with keyboard support. Depending on the keyboard configuration
settings, either the physical or the virtual keyboard can be used.

If the physical keyboard is configured, activating the keyboard will switch off
all other hotkeys as well as pad functions. All keyboard input is routed to
the emulated keyboard, as configured in the physical keyboard mapping.

The virtual keyboard displays an overlay when activated. The currently selected
key is highlighted, and the selection can be changed with the left, right, up,
and down keys. Pressing the A button will send the selected key to the emulated
keyboard. Pressing B will show what the key value would be if the emulated Shift
key is active. The C button will move the keyboard overlay from the top of the
screen to the bottom and vice versa.

All meta keys, like Shift, Ctrl, have a built-in toggle function. Pressing the
A button on them will toggle their state between pressed and released. Depending
on the state the color of the key changes slightly. Only one meta key can be
active at the same time.


Other important stuff
---------------------

* Sega/Mega CD: If the background music is missing, the CD image format may be
  wrong. Currently .cue/bin or .chd is recommended. Be aware that there are
  lots of bad dumps on the web, and some use mp3 format for audio, which often
  causes problems (see below).
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
* When using mp3s, use lower bitrate for better performance (96 or 128kbps
  CBRs recommended).
* GP2X F100/F200: When you use both GP2X CPUs, keep in mind that you can't
  overclock as high as when using ARM920 only. For example my GP2X when run
  singlecore can reach 280MHz, but with both cores it's about 250MHz. When
  overclocked too much, it may start hanging and producing random noise, or
  causing ARM940 crashes ("940 crashed" message displayed).
* GP2X F100/F200: Due to internal implementation mp3s must not be larger that
  12MB (12582912 bytes). Larger mp3s will not be fully loaded.
#endif


Options
-------

@@0. "Region"
This option lets you force the game to think it is running on machine from the
specified region, or just to set autodetection order. Also affects Sega/Mega CD.

@@0. "Hotkey save/load slot"
This is a slot number to use for savestates, when done by a button press outside
menu. This can also be configured to be changed with a button
(see "Key configuration").

@@0. "Interface options"
Enters Interface options menu (see below).

@@0. "Display options"
Enters Display options menu (see below).

@@0. "Sound options"
Enters Sound options menu (see below).

@@0. "MD/Genesis/Pico options"
Enters Mega Drive/Genesis/Pico options menu (see below).

@@0. "Sega/Mega CD add-on"
Enters Sega/Mega CD options menu (see below).

@@0. "32X add-on"
Enters 32X options menu (see below).

@@0. "SG/SMS/GG options"
Enters SG-1000/SC-3000/Master System/Game Gear options menu (see below).

@@0. "Advanced options"
Enters advanced options menu (see below).

@@0. "Restore defaults"
Restores all options (except controls) to defaults.


Interface options
-----------------

@@1. "Save global options"
If you save your config here it will be loaded on next ROM load, but only if
there is no game specific config saved (which will be loaded in that case).
You can press left/right to switch to a different config profile.

@@1. "Save game options"
Whenever you load current ROM again these settings will be loaded.

@@1. "Show FPS"
Self-explanatory. Format is XX/YY, where XX is the number of rendered frames and
YY is the number of emulated frames per second.

@@1. "Confirm save/load"
Allows to enable confirmation on saving (to prevent savestate overwrites), on
loading (to prevent destroying current game progress), and on both or none, when
using shortcut buttons (not menu) for saving/loading.

@@1. "Don't save last used ROM"
This will disable writing last used ROM to config on exit (what might cause SD
card corruption according to DaveC).


Display options
---------------
#ifdef GENERIC

@@2. "Video output mode"
SDL Window:
This is the default mode on portable devices, used if no overlay modes are
available. Window size is fixed at 320x240.
Video Overlay:
Used if hardware accelerated overlay scaling is available. Supports flexible
window sizes. The "2X" version has a higher color resolution but is slower.
#endif

@@2. "Frameskip"
How many frames to skip rendering before displaying another.
"Auto" is recommended.

@@2. "Max auto frameskip"
How many frames to skip rendering at most if Frameskip is "Auto".

#ifdef GENERIC
@@2. "Horizontal scaling"
This allows to resize the displayed image. "OFF" is unscaled, "software" uses
a smoothing filter to scale the image. "hardware" uses a hardware scaler for
better performance. Hardware scaling is not available on every device.

@@2. "Vertical scaling"
This allows to resize the displayed image. "OFF" is unscaled, "software" uses
a smoothing filter to scale the image. "hardware" uses a hardware scaler for
better performance. Hardware scaling is not available on every device.

@@2. "Scaler type"
Selects the filtering the software scaler will apply. "nearest" is unfiltered,
"bilinear" makes the image smoother but blurrier.
#endif
#ifdef PANDORA
@@2. "Filter"
Selects filter type used for image filtering.

Other options allow to set up scaling, filtering and vertical sync.
#endif
#ifdef GP2X
@@2. "Gamma correction"
F100/F200 only: Alters image gamma through GP2X hardware. Larger values make
image to look brighter, lower - darker (default is 1.0).

@@2. "Horizontal scaling"
This allows to resize the displayed image. "OFF" is unscaled, "software" uses
a smoothing filter to scale the image. F100/F200 only: "hardware" uses a
hardware scaler for better performance.

@@2. "Vertical scaling"
This allows to resize the displayed image. "OFF" is unscaled, "software" uses
a smoothing filter to scale the image. F100/F200 only: "hardware" uses a
hardware scaler for better performance.

@@2. "Tearing Fix"
Wiz only: works around the tearing problem by using portrait mode. Causes ~5-10%
performance hit, but eliminates the tearing effect.

@@2. "Vsync"
This one adjusts the LCD refresh rate to better match game's refresh rate and
starts synchronizing rendering with it. Should make scrolling smoother and
eliminate tearing on F100/F200.
#endif
#ifdef GIZ
@@2. "Scanline mode"
This option was designed to work around slow framebuffer access (the Gizmondo's
main bottleneck) by drawing every other line (even numbered lines only).
This improves performance greatly, but looses detail.

@@2. "Scale low res mode"
The Genesis/Mega Drive had several graphics modes, some of which were only 256
pixels wide. This option scales their width to 320 by using simple
pixel averaging scaling. Works only when 16bit renderer is enabled.

@@2. "Double buffering"
Draws the display to offscreen buffer, and flips it with visible one when done.
Unfortunately this causes serious tearing, unless v-sync is used (next option).

@@2. "Wait for V-sync"
Waits for vertical sync before drawing (or flipping buffers, if previous option
is enabled). Emulation is stopped while waiting, so this causes large performance
hit.
#endif
#ifdef PSP
@@2. "Horizontal scaling"
This allows to resize the displayed image by using the PSP's hardware. "OFF" is
unscaled, "4:3" is closest to the original Mega Drive screen, "fullscreen" uses
the full screen width.

@@2. "Vertical scaling"
This allows to resize the displayed image by using the PSP's hardware. "OFF" is
unscaled, "4:3" is closest to the original Mega Drive screen, "fullscreen" uses
the full screen height.

@@2. "Scaler type"
Selects the filtering the PSP hardware will apply for scaling. "Bilinear" makes
the image smoother but blurrier.

@@2. "Gamma adjustment"
Color gamma can be adjusted with this.

@@2. "Black level"
This can be used to reduce unwanted "ghosting" effect for dark games, by making
black pixels brighter. Use together with "gamma adjustment" for more effect.

@@2. "Wait for v-sync"
If enabled, wait for the screen to finish updating before switching to next
frame, to avoid tearing.
#endif


Sound options
-------------

@@3. "Enable sound"
Does what it says.

@@3. "Sound Quality"
#ifdef PSP
Sound sample rate. Lower rates improve performance but sound quality is lower.
22050Hz setting is the recommended one.
#else
Sound sample rate and stereo mode. Lower rates improve performance but sound
quality is lower.
#endif

@@3. "Sound filter"
Enables a low pass filter, similar to filtering in the real Mega Drive hardware.

@@3. "Filter strength"
Controls the sound filter. Higher values have more impact.


Mega Drive/Genesis/Pico options
-------------------------------
#ifndef PANDORA

@@4. "Renderer"
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

@@4. "FM audio"
This enables emulation of six-channel FM sound synthesizer chip, which was used
to produce sound effects and music.

@@4. "FM filter"
This filter makes the sound output more accurate, but it is slower, especially
for lower sound rates.

@@4. "FM DAC noise"
Makes the sound output more like a first model Mega Drive/Genesis if enabled.
Later models had an improved FM chip without the DAC noise.


Sega/Mega CD add-on
-------------------

@@5. "Save RAM cart"
Here you can enable 64K RAM cart. Format it in BIOS if you do.

@@5. "CD LEDs"
The Sega/Mega CD unit had two blinking LEDs (red and green) on it. This option
will display them on top-left corner of the screen.

@@5. "CDDA audio"
This option enables CD audio playback.

@@5. "PCM audio"
This enables 8 channel PCM sound source. It is required for some games to run,
because they monitor state of this audio chip.


32X add-on
----------

@@6. "32X renderer"
This currently only affects how the Genesis/MD layers are rendered, which is
same as "Renderer" in display options.

@@6. "PWM audio"
Emulates PWM sound portion of 32X hardware. Disabling this may greatly improve
performance for games that dedicate one of SD2s for sound, but will cause
missing sound effects and instruments.

@@6. "PWM IRQ optimization"
Enabling this may improve performance, but may also introduce sound glitches.


SG/Master System/Game Gear options
----------------------------------

@@7. "System"
Selects which of the Sega 8 bit systems is emulated. "auto" is recommended.

@@7. "Cartridge mapping"
Some cartridges have hardware to enable additional capabilities, e.g. mapping
excess ROM storage or acessing a battery backed RAM storage. "auto" is
recommended, but in some rare cases it may be needed to manually select this.

@@7. "Game Gear LCD ghosting"
The Game Gear LCD display had a very noticeable inertia for image changes. This
setting enables emulating the effect, with "weak" being recommended.

@@7. "FM sound unit"
The Japanese Master System (aka Mark III) has an extension slot for an FM sound
unit. Some games made use of this for providing better music and effects.
Disabling this improves performance for games using the FM unit, and usually
means falling back to the non-FM sound.

@@7. "SMS palette in TMS modes"
The Master System graphics chip can emulate the TMS grafic modes used in MSX and
SG-1000 games, but it is using a color palette which is much darker and the
colours aren't a good match. This option uses the original color palette of the
TMS graphics chip, which gives better results for MSX/SG-1000 ports.

Advanced options
----------------

@@8. "Disable frame limiter"
This allows games to run faster then 50/60fps, useful for benchmarking.

@@8. "Disable sprite limit"
The Mega Drive/Genesis had a limit on how many sprites (usually smaller moving
objects) can be displayed on single line. This option allows to disable that
limit. Note that some games used this to hide unwanted things, so it is not
always good to enable this option.

@@8. "Disable idle loop patching"
Idle loop patching is used to improve performance, but may cause compatibility
problems in some rare cases. Try disabling this if your game has problems.

@@8. "Emulate Game Gear LCD"
Disabling this option displays the full Game Gear VDP image with the normally
invisible borders.

@@8. "Enable dynarecs"
This enables dynamic recompilation for SH2 and SVP CPU code, which is improving
emulation performance greatly. SVP dynarec is only available on 32 bit ARM CPUs.

@@8. "Master SH2 cycles" / "Slave SH2 cycles"
This allows underclocking the 32X CPUs for better emulation performance. The
number has the same meaning as cycles in DOSBox, which is cycles per millisecond.
Underclocking too much may cause various in-game glitches.
#ifdef GP2X

@@8. "Use ARM940 core for sound"
F100/F200: This option causes PicoDrive to use ARM940T core (GP2X's second CPU)
for sound (i.e. to generate YM2612 samples) to improve performance noticeably.
It also decodes MP3s in Sega/Mega CD mode.
#endif


Key configuration
-----------------

Select "Configure controls" from the options menu. The "Player <n>" entry allows
for selecting a player with the left/right buttons. Then selecting "Player <n>"
will display 2 columns. The left column lists names of Genesis/MD controller
buttons, the right column shows which key on your handheld is assigned to it.

There is also option to enable 6 button pads (will allow you to configure XYZ
buttons), and an option to set turbo rate (in Hz) for turbo buttons.

Players 3 and 4 can only be used if a 4 player adapter is selected for input
device 1, and the game is supporting this. Only 3 button pads are currently
supported in 4 player mode.


Keyboard configuration
----------------------

The SC-3000 and the Sega Pico can use a keyboard as input device. Select
"Configure controls" to configure keyboard support in PicoDrive. The "Keyboard"
entry allows choosing the keyboard type by using the left/right buttons. The
virtual keyboard doesn't need any configuration. For configuring the physical
keyboard mapping, select "Keyboard" when the physical keyboard is selected.

Physical host keyboard keys are mapped 1:1 on emulated keyboard keys. Only the
unmodified base keys (like A, 1 etc) can be mapped. Don't use Shift, Ctrl or
Alt when changing the mapping, as it won't work. The default mapping matches
a standard American PC104 keyboard.


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

SG-1000/SC-3000/Master System/Game Gear:
z80 @ 3.6MHz: yes, DrZ80 (on 32 bit ARM CPUs) or CZ80 core
VDP: yes, all SG/SMS/GG modes, except some quirks not used by games
YM2413 FM: yes, digital-sound-antiques core
SN76489 PSG: yes, MAME core
Some in-cart mappers are also supported.

Genesis/Mega Drive:
main 68k @ 7.6MHz: yes, Cyclone (on 32 bit ARM CPUs) or FAME/C core
z80 @ 3.6MHz: yes, DrZ80 (on 32 bit ARM CPUs) or CZ80 core
VDP: yes, except some quirks and mode 4, not used by games
YM2612 FM: yes, optimized MAME core
SN76489 PSG: yes, MAME core
SVP chip: yes! This is first emu to ever do this
Pico PCM: yes, MAME core
Some Mega Drive/Genesis in-cart mappers are also supported.

Sega/Mega CD:
another 68k @ 12.5MHz: yes, Cyclone or FAME/C too
gfx scaling/rotation chip (custom ASIC): yes
PCM sound source: yes
CD-ROM controller: yes (mostly)
bram (internal backup RAM): yes
RAM cart: yes

32X:
2x SH2 @ 23MHz: yes, MAME core or custom recompiler
Super VDP: yes
PWM: yes

Pico:
main 68k @ 7.6MHz: yes, Cyclone (on 32 bit ARM CPUs) or FAME/C core
VDP: yes, except some quirks and mode 4, not used by games
SN76489 PSG: yes, MAME core
ADPCM: yes, MAME core
Pico Pen: yes
Pico Storyware pages: yes
Pico pad overlays: yes


Problems / limitations
----------------------

#ifdef PSP
* SVP emulation is terribly slow.
#endif
* Various VDP modes and quirks (window bug, scroll size 2, etc.) are not
  perfectly emulated, as very few games use this (if any at all).
* The emulator is designed for speed and not 100% accurate, so some things may
  not work as expected.
* The FM sound core doesn't support all features and has some accuracy issues.


Changelog
---------

#include "../ChangeLog"


Credits
-------

This emulator is made of the code from following people/projects:

#include "../AUTHORS"


License
-------

This program and its code is released under the terms of MAME license:
#include "../COPYING"

SEGA/Master System/Game Gear/Genesis/Mega Drive/SEGA CD/Mega CD/32X/Pico are
trademarks of Sega Enterprises Ltd.

