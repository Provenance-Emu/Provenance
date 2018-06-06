<?php require("docgen.inc"); ?>

<?php BeginPage('sms', 'Sega Master System'); ?>

<?php BeginSection('Introduction', 'Section_intro'); ?>
Mednafen's Sega Master System emulation is based off of <a href="http://www.techno-junk.org/">SMS Plus</a>.
<p>
Sega Master System emulation in Mednafen is a low-priority system in terms of proactive maintenance and bugfixes.
</p>
<?php EndSection(); ?>

<?php PrintCustomPalettes(); ?>

<?php PrintSettings(); ?>

<?php EndPage(); ?>

