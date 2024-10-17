<?php require("docgen.inc"); ?>

<?php BeginPage('sasplay', 'Sega Arcade SCSP Player'); ?>

<?php BeginSection('Introduction', "Section_intro"); ?>
This module supports playing the SCSP-generated music from most Sega Model 2A, 2B, 2C and 3 games.  Model 3 4-channel audio is downmixed to stereo.
Original Model 2 games using the Sega MultiPCM chips are not supported.  MPEG music is not supported.
<p>
Some games, especially Model 3, may play music at up to a 2% faster tempo than they should.  This is likely due to their timing-sensitive interrupt handlers
combined with Mednafen's lack of emulation of dynamic SCSP wait states and interrupt signaling delays.
<p>
MAME-style ROM image filenames are expected.  A game's ROM image set should be loaded either via ZIP archive, ideally with no extraneous files in the archive, or by
specifying the path of the sound program ROM image.
<p>
Output volume is adjusted on a per-game basis via an internal database.  Some games(e.g. "Virtua Fighter 3") also have per-song/composition volume adjustments as well.
<?php EndSection(); ?>

<?php PrintSettings(); ?>

<?php EndPage(); ?>
