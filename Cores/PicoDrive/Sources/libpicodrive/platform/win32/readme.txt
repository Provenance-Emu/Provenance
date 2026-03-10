
About
-----

This is a quick windows port of PicoDrive, a Megadrive / Genesis emulator for
handheld devices. It was originally coded having ARM CPU based devices in mind
(most work was done on GP2X version), but there is also a PSP port.

The reason I'm sometimes doing windows versions is to show certain emulation
possibilities, first release was to demonstrate SVP emulation (Virtua Racing),
later Pico toy and X-Men 32X prototype. It is not to compete with other
emulators like Kega Fusion and the likes.

For more info, visit http://notaz.gp2x.de/svp.php


Releases
--------

1.70  - preliminary 32X emulation, runs X-Men proto.
1.45a - Few bugfixes and additions.
1.45  - Added preliminary Sega Pico emulation.
1.40b - Perspective fix thanks to Pierpaolo Prazzoli's info.
1.40a - Tasco Deluxe's dithering fix.
1.40  - first release.


Controls
--------

These are currently hardcoded, keyboard only:

PC      Gen/MD      Sega Pico
-------+-----------+---------
Enter:  Start
A:      A
S:      B           red button
D:      C           pen push
Q,W,E:  X,Y,Z
TAB:            (reset)
Esc:           (load ROM)
Arrows:          D-pad

It is possible to change some things in config.cfg (it is created on exit),
but possibilities are limited.


Credits
-------

Vast majority of code written by notaz (notasasatgmailcom).

A lot of work on making SVP emulation happen was done by Tasco Deluxe, my
stuff is a continuation of his. Pierpaolo Prazzoli's information and his
SSP1610 disassembler in MAME code helped a lot too.

The original PicoDrive was written by fDave from finalburn.com

This PicoDrive version uses bits and pieces of from other projects:

68k: FAME/C core, by Chui and Stéphane Dallongeville (as C68K).
z80: CZ80 by Stéphane Dallongeville and modified by NJ.
YM2612, SN76496 and SH2 cores: MAME devs.

Special thanks (ideas, valuable information and stuff):
Charles MacDonald, Eke, Exophase, Haze, Lordus, Nemesis,
Pierpaolo Prazzoli, Rokas, Steve Snake, Tasco Deluxe.

Greets to all the sceners and emu authors out there!

