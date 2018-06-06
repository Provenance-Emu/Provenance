<?php require("docgen.inc"); ?>

<?php BeginPage('ss', 'Sega Saturn'); ?>

<?php BeginSection('Introduction', "Section_intro"); ?>
<p>
<font color="orange" size="+1"><b>NOTE:</b></font> The Sega Saturn emulation is currently experimental and under active development.  By default(and for the official releases for Windows), Saturn emulation is only compiled in for builds for some 64-bit architectures(x86_64, AArch64, PPC64).  The separate <a href="ssfplay.html">SSF playback module</a> does not have this limitation.
</p>
<p>
Mednafen's Sega Saturn emulation is extremely CPU intensive.  The minimum recommended CPU is a quad-core Intel Haswell-microarchitecture CPU with
a base frequency of >= 3.3GHz and a turbo frequency of >= 3.7GHz(e.g. Xeon E3-1226 v3), but note that this recommendation does not apply to any unofficial ports or forks,
which may have higher CPU requirements.
</p>

<p>
Save states are supported, but the data is not fully sanitized properly on save state load, so definitely <font color="red">avoid loading save states acquired from sources you don't trust</font>(this includes via netplay).
</p>

<p>
Enabling CD image preloading into memory via the <a href="mednafen.html#cd.image_memcache">cd.image_memcache</a> setting is recommended, to
avoid short emulator pauses and audio pops due to waiting for disk accesses to complete when the emulated CD is accessed.
</p>

<p>
A list of known emulation bugs(with workarounds in some cases) in Saturn games with Mednafen is available at <a href="https://forum.fobby.net/index.php?t=msg&th=1357">https://forum.fobby.net/index.php?t=msg&th=1357</a>
</p>

<?php EndSection(); ?>

<?php BeginSection("Firmware/BIOS", "Section_firmware_bios"); ?>
<p>
Place the correct BIOS image files in the <a href="mednafen.html#Section_firmware_bios">correct location</a>.
</p>

<p>
The filenames listed below are per default ss.bios_* settings.
</p>
<table border>
 <tr><th>Filename:</th><th>Purpose:</th><th>SHA-256 Hash:</tr>
 <tr><td>sega_101.bin</td><td>BIOS image.<br>Required for Japan-region games.</td><td>dcfef4b99605f872b6c3b6d05c045385cdea3d1b702906a0ed930df7bcb7deac</td></tr>
 <tr><td>mpr-17933.bin</td><td>BIOS image.<br>Required for North America/US-region and Europe-region games.</td><td>96e106f740ab448cf89f0dd49dfbac7fe5391cb6bd6e14ad5e3061c13330266f</td></tr>
</table>
<?php EndSection(); ?>

<?php BeginSection('Default Input Mappings', 'Section_default_keys'); ?>

 <?php BeginSection('Digital Gamepad on Virtual Port 1', 'Section_default_keys_gamepad'); ?>
  <p>
  <table border>
   <tr><th>Key:</th><th nowrap>Emulated Button:</th></tr>

   <tr><td>W</td><td>Up</td></tr>
   <tr><td>S</td><td>Down</td></tr>
   <tr><td>A</td><td>Left</td></tr>
   <tr><td>D</td><td>Right</td></tr>

   <tr><td>Enter</td><td>START</td></tr>

   <tr><td>Keypad 1</td><td>A</td></tr>
   <tr><td>Keypad 2</td><td>B</td></tr>
   <tr><td>Keypad 3</td><td>C</td></tr>

   <tr><td>Keypad 4</td><td>X</td></tr>
   <tr><td>Keypad 5</td><td>Y</td></tr>
   <tr><td>Keypad 6</td><td>Z</td></tr>

   <tr><td>Keypad 7</td><td>Left Shoulder</td></tr>
   <tr><td>Keypad 9</td><td>Right Shoulder</td></tr>
  </table>
  </p>
 <?php EndSection(); ?>

 <?php BeginSection('Mouse on Virtual Ports 1-12', 'Section_default_keys_mouse'); ?>
  <p>
  <font color="yellow">NOTE:</font> The default mapping for the emulated mouse "START" button conflicts with the default mapping for the "Enter" key on the emulated keyboards on all virtual ports,
  and the default mapping for "START" on the emulated digital gamepad on virtual port 1.  If you want to use an emulated mouse with an emulated keyboard, you should probably
  remap the "START" button to a non-keyboard host device.
  <table border>
   <tr><th>Button:</th><th nowrap>Emulated Button:</th></tr>
   <tr><td nowrap>Mouse, Left Button</td><td>Left Button</td></tr>
   <tr><td nowrap>Mouse, Right Button</td><td>Right Button</td></tr>
   <tr><td nowrap>Mouse, Middle Button</td><td>Middle Button</td></tr>
   <tr><td nowrap>Keyboard, Enter</td><td>START</td></tr>
  </table>
  </p>
 <?php EndSection(); ?>

 <?php BeginSection('Light Gun on Virtual Ports 1-12', 'Section_default_keys_gun'); ?>
  <p>
   <table border>
   <tr><th>Button:</th><th nowrap>Emulated Button:</th></tr>
   <tr><td nowrap>Mouse, Left Button</td><td>Trigger</td></tr>
   <tr><td nowrap>Mouse, Middle Button</td><td>START</td></tr>
   <tr><td nowrap>Mouse, Right Button</td><td>Offscreen Shot(simulated)</td></tr>
   </table>
  </p>
 <?php EndSection(); ?>

<?php EndSection(); ?>


<?php PrintSettings(); ?>

<?php EndPage(); ?>
