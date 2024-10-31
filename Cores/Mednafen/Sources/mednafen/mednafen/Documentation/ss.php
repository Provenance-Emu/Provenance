<?php require("docgen.inc"); ?>

<?php BeginPage('ss', 'Sega Saturn'); ?>

<?php BeginSection('Introduction', "Section_intro"); ?>
<p>
<font color="orange" size="+1"><b>NOTE:</b></font> The Sega Saturn emulation is currently under active development.  By default(and for the official releases for Windows), Saturn emulation is only compiled in for builds for some 64-bit architectures(x86_64, AArch64, PPC64).  The separate <a href="ssfplay.html">SSF playback module</a> does not have this limitation.
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

<p>
Mednafen's Sega Saturn emulation should not be used in lieu of a Sega Saturn for authoritative game performance/FPS review purposes.  The emulation will generally
run Saturn games with less slowdown than on a real Saturn, even when more accurate emulation modes are enabled via internal databases.
</p>

<?php EndSection(); ?>

<?php BeginSection("Firmware/BIOS", "Section_firmware_bios"); ?>
<p>
Place the correct BIOS image files in the <a href="mednafen.html#Section_firmware_bios">correct location</a>.  If you don't intend to emulate the arcade ST-V at all,
you don't need to provide the corresponding ST-V BIOS files.
</p>

<p>
The filenames listed below are per default ss.bios_* settings.
</p>
<table border>
 <tr><th>Filename:</th><th>Purpose:</th><th>SHA-256 Hash:</tr>
 <tr><td>sega_101.bin</td><td>BIOS image.<br>Required for Japan-region games.</td><td>dcfef4b99605f872b6c3b6d05c045385cdea3d1b702906a0ed930df7bcb7deac</td></tr>
 <tr><td>mpr-17933.bin</td><td>BIOS image.<br>Required for North America/US-region and Europe-region games.</td><td>96e106f740ab448cf89f0dd49dfbac7fe5391cb6bd6e14ad5e3061c13330266f</td></tr>
 <tr><th colspan=3"><a name="Section_firmware_bios_stv"><hr></a></th></tr>
 <tr><td>epr-20091.ic8</td><td>ST-V BIOS image.<br>Required for Japan-region ST-V games.</td><td>ac778ec04aaa4df296d30743536da3de31281f8ae5c94d7be433dcc84e25d85b</td></tr>
 <tr><td>epr-17952a.ic8</td><td>ST-V BIOS image.<br>Required for North America/US-region ST-V games.</td><td>bac5a52794cf424271f073df228e0b0eb042dede6a3b829eb49abf155e7e0137</td></tr>
 <tr><td>epr-17954a.ic8</td><td>ST-V BIOS image.<br>Required for Europe-region ST-V games.</td><td>3e6f91506031badc4ebdf7fe5b4f33180222a369b575522861688d3b27322a68</td></tr>
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

<?php BeginSection('ST-V', 'Section_stv'); ?>
<p>
 Mednafen has experimental support for ST-V games that don't require special expansion hardware nor use a decryption or decompression chip.
 <a href="#Section_firmware_bios_stv">ST-V-specific BIOS files</a> are required.
 The games should be loaded via ZIP archives, one variant of one game per archive, with all ROM image files in the same directory in the archive, and ideally
 with no extraneous files that may confuse autodetection.  Lowercase MAME-style filenames must be used.  For testing purposes, an ST-V game outside of an archive may also be played by loading the first boot/program ROM image file.
</p>
<p>
 Upon loading a supported ST-V game, a suitable emulated Saturn input device is selected automatically, and input data is remapped internally to the form the
 emulated ST-V hardware needs.  For most games, the device selected is the Digital Gamepad("gamepad"), but for "Critter Crusher" and "Tatacot", it is Light Gun("gun").
</p>
<p>
 ST-V Service, Test, and Pause currently cannot be remapped inside Mednafen itself, due to limitations that may be resolved in a future version.  They can still
 be <a href="mednafen.html#Section_input_mapping_format">remapped manually</a>, however.
</p>
<p>
  <table border>
   <tr><th colspan="3">Default Key Mappings:</th></tr>
   <tr><th>Key:</th><th nowrap>Emulated Function:</th><th>Mapping Setting:</th></tr>
   <tr><td><a href="mednafen.html#command.insert_coin">F8</a></td><td>Coin Insertion Trigger</td><td>command.insert_coin</td></tr>
   <tr><td colspan="3"><hr></td></tr>
   <tr><td nowrap>"Keypad -" + "Keypad /"</td><td>Test Button</td><td>ss.input.builtin.builtin.stv_test</td></tr>
   <tr><td nowrap>"Keypad -" + "Keypad +"</td><td>Service Button</td><td>ss.input.builtin.builtin.stv_service</td></tr>
   <tr><td nowrap>"Keypad -" + "Keypad Enter"</td><td>Pause Button <i>(Requires game support, may cause malfunctions)</i></td><td>ss.input.builtin.builtin.stv_pause</td></tr>
  </table> 
</p>
<p>
The following ST-V games and game variants are explicitly supported:
<ul>
 <li>Baku Baku Animal
 <li>Columns '97
 <li>Cotton 2
 <li>Cotton Boomerang
 <li>Critter Crusher
 <li>DaeJeon! SanJeon SuJeon
 <li>Danchi de Hanafuda
 <li>Die Hard Arcade
 <li>Dynamite Deka
 <li>Ejihon Tantei Jimusyo
 <li>Final Arch
 <li>Funky Head Boxers
 <li>Golden Axe: The Duel
 <li>Groove on Fight: Gouketsuji Ichizoku 3
 <li>Guardian Force
 <li>Karaoke Quiz Intro Don Don!
 <li>Maru-Chan de Goo!
 <li>Mausuke no Ojama the World
 <li>Othello Shiyouyo
 <li>Pebble Beach: The Great Shot
 <li>Purikura Daisakusen
 <li>Puyo Puyo Sun
 <li>Puzzle &amp; Action: BoMulEul Chajara
 <li>Puzzle &amp; Action: Sando-R
 <li>Puzzle &amp; Action: Treasure Hunt
 <li>Radiant Silvergun <i>(special handling to simulate home console port's extra buttons)</i>
 <li>Sakura Taisen: Hanagumi Taisen Columns
 <li>Sea Bass Fishing
 <li>Shanghai: The Great Wall
 <li>Shienryu
 <li>Soukyu Gurentai
 <li>Suiko Enbu
 <li>Super Major League
 <li>Taisen Tanto-R Sashissu!!
 <li>Tatacot
 <li>Virtua Fighter Kids
 <li>Virtua Fighter Remix
 <li>Winter Heat
 <li>Zen Nippon Pro-Wrestling Featuring Virtua
</ul>

The following ST-V games are currently broken due to missing emulation of the decryption/decompression chips:
<ul>
 <li>Astra SuperStars
 <li>Decathlete
 <li>Final Fight Revenge
 <li>Steep Slope Sliders
 <li>Tecmo World Cup '98
 <li>Touryuu Densetsu Elan Doree
</ul>
</p>
<?php EndSection(); ?>

<?php BeginSection('Bootable ROM Cart', 'Section_bootromcart'); ?>
Mednafen supports bootable cart ROM images up to 48MiB in size, with a filename extension of "ss".
<p>
The first 32MiB is mapped into A-bus CS0, and the ROM data beyond 32MiB is mapped into A-bus CS1; both are mapped as 16-bit ROM.
If the ROM image is 32MiB or smaller, a standard 512KiB of non-volatile cart backup memory will be provided in the A-bus CS1 area instead
of ROM data.
<?php EndSection(); ?>

<?php PrintInternalDatabases(); ?>

<?php PrintSettings(); ?>

<?php EndPage(); ?>
