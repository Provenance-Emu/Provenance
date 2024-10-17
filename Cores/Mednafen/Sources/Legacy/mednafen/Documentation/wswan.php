<?php require("docgen.inc"); ?>

<?php BeginPage('wswan', 'WonderSwan'); ?>

<?php BeginSection('Introduction', 'Section_intro'); ?>

Mednafen's WonderSwan (Color) emulation is based off of <a href="http://cygne.emuunlim.com/">Cygne</a>, modified with bug fixes
and to add sound emulation.

<p>
WSR(WonderSwan sound rip format) playback is supported.
</p>

<?php EndSection(); ?>

<?php BeginSection('Default Key Assignments', 'Section_default_keys'); ?>

 The "X Cursor" buttons are usually used for directional control with horizontal-layout games, 
 while the "Y Cursor" buttons are usually used for directional control with vertical-layout games.
 Additionally, the opposite buttons are often treated as action buttons...because of this,
 <big><b>you must *NOT* configure the X cursor buttons and Y cursor buttons to the same real buttons or keys.</b></big>  Games will not behave
 well at all if you do.
 </p>
 <p>
 <table border>
  <tr><th>Key(s):</th><th>Action:</th><th>Configuration String:</th></tr>
  <tr><td>ALT + SHIFT + 1</td><td>Activate in-game input configuration process for WonderSwan pad.</td><td>input_config1</td></tr>
 </table>
 </p>
 <p>
 <table border>
  <tr><th>Key:</th><th nowrap>Action/Button:</th></tr>
  <tr><td>Keypad 2</td><td>B</td></tr>
  <tr><td>Keypad 3</td><td>A</td></tr>
  <tr><td>Enter/Return</td><td>Start</td></tr>
  <tr><td>W</td><td nowrap>Up, X Cursors</td></tr>
  <tr><td>S</td><td nowrap>Down, X Cursors</td></tr>
  <tr><td>A</td><td nowrap>Left, X Cursors</td></tr>
  <tr><td>D</td><td nowrap>Right, X Cursors</td></tr>
  <tr><td>UP</td><td nowrap>Up, Y Cursors</td></tr>
  <tr><td>DOWN</td><td nowrap>Down, Y Cursors</td></tr>
  <tr><td>LEFT</td><td nowrap>Left, Y Cursors</td></tr>
  <tr><td>RIGHT</td><td nowrap>Right, Y Cursors</td></tr>
 </table>

<?php EndSection(); ?>


<?php BeginSection("Game-specific Emulation Hacks", "Section_hax"); ?>
 <table border width="100%">
  <tr><th>Title:</th><th>Description:</th><th>Source code files affected:</th></tr>
  <tr><td>Detective Conan</td><td>Patch to work around lack of pipeline/prefetch emulation.</td><td>src/wswan/main.cpp</td></tr>
  </table>
<?php EndSection(); ?>


<?php PrintSettings(); ?>

<?php EndPage(); ?>

