<?php require("docgen.inc"); ?>

<?php BeginPage('ngp', 'Neo Geo Pocket (Color)'); ?>

<?php BeginSection('Introduction', 'Section_intro'); ?>
Mednafen's Neo Geo Pocket emulation is based off of <b>NeoPop</b>.
<p>
The Neo Geo Pocket (Color) emulation in Mednafen is not very accurate in terms of low-level details; BIOS is HLE'd, CPU instruction
timing is totally fubared, and some CPU instructions are likely emulated incorrectly.
It's sufficient to play most of the commercially released games fairly well, but if you want to do NGP(C) homebrew development,
you're better off at looking at something like <a href="http://mamedev.org">MAME</a>.
</p>


<?php EndSection(); ?>

<?php BeginSection('Default Key Assignments', 'Section_default_keys'); ?>
 <table border>
  <tr><th>Key(s):</th><th>Action:</th><th>Configuration String:</th></tr>
  <tr><td>ALT + SHIFT + 1</td><td>Activate in-game input configuration process for Neo Geo Pocket pad.</td><td>input_config1</td></tr>
 </table>
 </p>
 <p>
 <table border>
  <tr><th>Key:</th><th nowrap>Action/Button:</th></tr>
  <tr><td>Keypad 2</td><td>A</td></tr>
  <tr><td>Keypad 3</td><td>B</td></tr>
  <tr><td>Enter/Return</td><td>Option</td></tr>
  <tr><td>W</td><td>Up</td></tr>
  <tr><td>S</td><td>Down</td></tr>
  <tr><td>A</td><td>Left</td></tr>
  <tr><td>D</td><td>Right</td></tr>
 </table>
<?php EndSection(); ?>

<?php PrintSettings(); ?>

<?php EndPage(); ?>

