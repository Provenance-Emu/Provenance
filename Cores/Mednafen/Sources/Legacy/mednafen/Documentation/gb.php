<?php require("docgen.inc"); ?>

<?php BeginPage('gb', 'Game Boy (Color)'); ?>

<?php BeginSection('Introduction', "Section_intro"); ?>
Mednafen's GameBoy (Color) emulation is based off of <b>VisualBoy Advance</b>.
<p>
Super Game Boy is presently not supported.  If it ever is supported in the future, it will likely be via the
<a href="snes.html">SNES</a> module instead of the GB module.
</p>
<?php EndSection(); ?>

<?php PrintCustomPalettes(); ?>

<?php BeginSection('Default Key Assignments', "Section_default_keys"); ?>
 <table border>
  <tr><th>Key(s):</th><th>Action:</th><th>Configuration String:</th></tr>
  <tr><td>ALT + SHIFT + 1</td><td>Activate in-game input configuration process for GameBoy pad.</td><td>input_config1</td></tr>
 </table>
 </p>
 <p>
 <table border>
  <tr><th>Key:</th><th nowrap>Action/Button:</th></tr>
  <tr><td>Keypad 2</td><td>B</td></tr>
  <tr><td>Keypad 3</td><td>A</td></tr>
  <tr><td>Enter/Return</td><td>Start</td></tr>
  <tr><td>Tab</td><td>Select</td></tr>
  <tr><td>W</td><td>Up</td></tr>
  <tr><td>S</td><td>Down</td></tr>
  <tr><td>A</td><td>Left</td></tr>
  <tr><td>D</td><td>Right</td></tr>
 </table>
<?php EndSection(); ?>

<?php PrintSettings(); ?>

<?php EndPage(); ?>

