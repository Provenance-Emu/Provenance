<?php require("docgen.inc"); ?>

<?php BeginPage('pce_fast', 'PC Engine (CD)/TurboGrafx 16 (CD)/SuperGrafx'); ?>

<?php BeginSection('Introduction', 'Section_intro'); ?>
<p>
The "pce_fast" emulation module is an experimental alternative to the <a href="pce.html">pce</a> emulation module.  It is
a fork of 0.8.x modified for speed at the expense of (usually) unneeded accuracy(this compares to the "pce" module,
which traded speed away in favor of accuracy).
</p>
<p>
To use this module rather than the "pce" module, you must either set the "pce.enable" setting to "0", or pass
"-force_module pce_fast" to Mednafen each time it is invoked.
</p>
<p>
<b>WARNING:</b> Save states, movies, and netplay are definitely not compatible between the "pce" module and the "pce_fast" module.
</p>
<?php EndSection(); ?>

<?php PrintCustomPalettes(); ?>

<?php PrintSettings(); ?>

<?php EndPage(); ?>

