<?php require("docgen.inc"); ?>

<?php BeginPage('pcfx', 'PC-FX'); ?>

<?php BeginSection('Introduction', 'Section_intro'); ?>
  <ul>
   <li>Internal backup memory and external backup memory are emulated.</li>
   <li>Motion decoder RLE and JPEG-like modes are emulated.</li>
   <li>KING Background 0 scaling+rotation mode is supported.</li>
   <li>Mouse emulation.</li>
   <li>Working CD+G playback.</li>
  </ul>
<?php EndSection(); ?>

<?php BeginSection("Firmware/BIOS", "Section_firmware_bios"); ?>
<p>
Place a correct BIOS image file in the <a href="mednafen.html#Section_firmware_bios">correct location</a>.
</p>

<p>
The filename listed below is per default <a href="#pcfx.bios">pcfx.bios</a> setting.
</p>
<table border>
 <tr><th>Filename:</th><th>SHA-1:</th><th>Description:</th></tr>
 <tr><td rowspan="3">pcfx.rom</td><td>1a77fd83e337f906aecab27a1604db064cf10074</td><td>PC-FX BIOS version 1.00.  Recommended BIOS version.</td></tr>
<!--
 <tr>                             <td>8b662f7548078be52a871565e19511ccca28c5c8</td><td>PC-FX BIOS version 1.01.</td></tr>
 <tr>                             <td>a9372202a5db302064c994fcda9b24d29bb1b41c</td><td>PC-FXGA BIOS.  Not recommended.</td></tr>
-->
</table>
<?php EndSection(); ?>


<?php BeginSection('Default Key Assignments', 'Section_default_keys'); ?>

 <table border>
  <tr><th>Key(s):</th><th>Action:</th><th>Configuration String:</th></tr>
  <tr><td>ALT + SHIFT + 1</td><td>Activate in-game input configuration process for device on virtual input port 1.</td><td>input_config1</td></tr>
  <tr><td>ALT + SHIFT + 2</td><td>Activate in-game input configuration process for device on virtual input port 2.</td><td>input_config2</td></tr>
 </table>
 </p>
 <p>
 <table border>
  <tr><th>Key:</th><th nowrap>Action/Button:</th></tr>
  <tr><td>Keypad 4</td><td>IV</td></tr>
  <tr><td>Keypad 5</td><td>V</td></tr>
  <tr><td>Keypad 6</td><td>VI</td></tr>
  <tr><td>Keypad 1</td><td>III</td></tr>
  <tr><td>Keypad 2</td><td>II</td></tr>
  <tr><td>Keypad 3</td><td>I</td></tr>
  <tr><td>Keypad 8</td><td>MODE 1</td></tr>
  <tr><td>Keypad 9</td><td>MODE 2</td></tr>
  <tr><td>Enter/Return</td><td>Run</td></tr>
  <tr><td>Tab</td><td>Select</td></tr>
  <tr><td>W</td><td>Up</td></tr>
  <tr><td>S</td><td>Down</td></tr>
  <tr><td>A</td><td>Left</td></tr>
  <tr><td>D</td><td>Right</td></tr>
 </table>

<?php EndSection(); ?>

<?php PrintSettings(); ?>

<?php EndPage(); ?>

