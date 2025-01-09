<?php require("docgen.inc"); ?>

<?php BeginPage('md', 'Sega Genesis/MegaDrive'); ?>

<?php BeginSection('Introduction', "Section_intro"); ?>
Mednafen's Sega Genesis/Megadrive emulation is based off of <a href="http://www.techno-junk.org/">Genesis Plus</a> and
information and code from <b>Genesis Plus GX</b>(old GPL-licensed version).  The GPL-incompatible
CPU and sound emulation cores in the aforementioned projects have been replaced with GPLed or GPL-compatible alternatives;
heavily-modified and improved YM2612 emulation from Gens, and Z80 emulation core from FUSE.
<p>
Sega Genesis/Megadrive emulation should still be considered experimental; there are still likely timing bugs in the 68K
emulation code, the YM2612 emulation code is not particularly accurate, and the VDP code has timing-related issues.
</p>

<p>
Sega 32X and Sega CD are not currently supported, though there is a bit of stub Sega CD code present currently.
</p>

<?php EndSection(); ?>

<?php PrintSettings(); ?>

<?php EndPage(); ?>

