<?php require("docgen.inc"); ?>

<?php BeginPage('gg', 'Sega Game Gear'); ?>

<?php BeginSection('Introduction', "Section_intro"); ?>
Mednafen's Sega Game Gear emulation is based off of <a href="http://www.techno-junk.org/">SMS Plus</a>.
<p>
Game Gear emulation in Mednafen is a low-priority system in terms of proactive maintenance and bugfixes.
</p>
<?php EndSection(); ?>

<?php PrintCustomPalettes(); ?>

<?php PrintSettings(); ?>

<?php EndPage(); ?>

