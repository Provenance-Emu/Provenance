<?php require("docgen.inc"); ?>

<?php BeginPage('snes', 'Super Nintendo Entertainment System/Super Famicom'); ?>

<?php BeginSection('Introduction', 'Section_intro'); ?>
Mednafen's primary SNES emulation module is a fork of <a href="http://byuu.org/">bsnes</a> v0.059, with(but not limited to) the following modifications:
<ul>
 <li>Cx4 Op10 fix patch</li>
 <li>blargg_libco_ppc64-5</li>
 <li>nall serializer 64-bit type bugfix backport</li>
 <li>a few minor timing/scheduler related changes</li>
 <li>Minor SuperFX emulation optimizations</li>
 <li>Minor S-SMP emulation optimizations</li>
 <li>Modified blending behavior when in hi-res modes</li>
</ul>
<p>
SNSF playback is supported to a degree; however, its implementation in Mednafen is incomplete.
</p>
<p>
SPC playback is not supported, but it is supported (experimentally) by the <b><a href="snes_faust.html">snes_faust</a></b> module.
</p>
<p>
<b><font color="red">WARNING:</font></b> Saving state(and by extension rewinding and netplay) with this module's SNES emulation may break some games.
"Tales of Phantasia" is a known problematic game in this regard.
</p>
<?php EndSection(); ?>

<?php PrintCustomPalettes(); ?>

<?php BeginSection('Default Key Assignments', 'Section_default_keys'); ?>

 <p>
 <table border>
  <tr><th colspan="2">Virtual Gamepad 1</th></tr>
  <tr><th>Key:</th><th nowrap>Button:</th></tr>
  <tr><td>W</td><td>Up</td></tr>
  <tr><td>S</td><td>Down</td></tr>
  <tr><td>A</td><td>Left</td></tr>
  <tr><td>D</td><td>Right</td></tr>
  <tr><th>Key:</th><th nowrap>Button:</th></tr>
  <tr><td>Tab</td><td>Select</td></tr>
  <tr><td>Enter/Return</td><td>Start</td></tr>
  <tr><th>Key:</th><th nowrap>Button:</th></tr>
  <tr><td>Keypad 4</td><td>Y</td></tr>
  <tr><td>Keypad 2</td><td>B</td></tr>
  <tr><td>Keypad 8</td><td>X</td></tr>
  <tr><td>Keypad 6</td><td>A</td></tr>
  <tr><th>Key:</th><th nowrap>Button:</th></tr>
  <tr><td>Keypad 7</td><td>Left Shoulder</td></tr>
  <tr><td>Keypad 9</td><td>Right Shoulder</td></tr>
 </table>
 </p>

 <p>
 <table border>
  <tr><th colspan="2">Virtual Super Scope</th></tr>
  <tr><th>Key:</th><th nowrap>Button:</th></tr>
  <tr><td>Mouse Left</td><td>Trigger</td></tr>
  <tr><td>Mouse Right</td><td>Cursor</td></tr>
  <tr><td>Mouse Middle</td><td>Pause</td></tr>
  <tr><td>End</td><td>Turbo</td></tr>
  <tr><td>Space</td><td>Offscreen Shot(Simulated)</td></tr>
 </table>
 </p>


<?php EndSection(); ?>

<?php PrintSettings(); ?>

<?php EndPage(); ?>

