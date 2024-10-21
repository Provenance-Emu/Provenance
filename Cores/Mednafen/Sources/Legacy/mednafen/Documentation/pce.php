<?php require("docgen.inc"); ?>

<?php BeginPage('pce', 'PC Engine/TurboGrafx 16 (CD)/SuperGrafx'); ?>

<?php BeginSection('Introduction', 'Section_intro'); ?> 
 <ul>
  <li>Sub-instruction timing granularity(but greater than cycle granularity)
  <li>All sprite sizes supported.</li>
  <li>16-sprites per line limit emulated.</li>
  <li>Accurate HuC6280 flags emulation.</li>
  <li>Dot-clock emulation for more accurate aspect ratios.</li>
  <li>Support for Street Fighter 2's HuCard hardware.</li>
  <li>Support for Populous's backup RAM.</li>
  <li>6-button pad emulation.</li>
  <li>Mouse emulation.</li>
  <li>Working CD+G playback.</li>
 </ul>
<?php EndSection(); ?>

<?php PrintCustomPalettes(); ?>

<?php BeginSection('Default Key Assignments', 'Section_default_keys'); ?>
 <p>
 <table border>
  <tr><th colspan="3">Hotkeys</th></tr>
  <tr><th>Key(s):</th><th>Action:</th><th>Setting Name:</th></tr>
  <tr><td>ALT + SHIFT + 1</td><td>Activate in-game input configuration process for gamepad 1.</td><td>input_config1</td></tr>
  <tr><td>ALT + SHIFT + 2</td><td>Activate in-game input configuration process for gamepad 2.</td><td>input_config2</td></tr>
  <tr><td>ALT + SHIFT + 3</td><td>Activate in-game input configuration process for gamepad 3.</td><td>input_config3</td></tr>
  <tr><td>ALT + SHIFT + 4</td><td>Activate in-game input configuration process for gamepad 4.</td><td>input_config4</td></tr>
  <tr><td>ALT + SHIFT + 5</td><td>Activate in-game input configuration process for gamepad 5.</td><td>input_config5</td></tr>
 </table>
 </p>

 <p>
 <table border>
  <tr><th colspan="2">Virtual Gamepad 1</th></tr>
  <tr><th>Key:</th><th nowrap>Button:</th></tr>
  <tr><td>Keypad 2</td><td>II</td></tr>
  <tr><td>Keypad 3</td><td>I</td></tr>
  <tr><td>Enter/Return</td><td>Run</td></tr>
  <tr><td>Tab</td><td>Select</td></tr>
  <tr><td>W</td><td>Up</td></tr>
  <tr><td>S</td><td>Down</td></tr>
  <tr><td>A</td><td>Left</td></tr>
  <tr><td>D</td><td>Right</td></tr>
 </table>
 </p>
<?php EndSection(); ?>

<?php BeginSection('Advanced Usage', 'Section_advanced'); ?>
 <?php BeginSection('Accidental Soft Resets', 'Section_advanced_softreset'); ?>
 <p>
  To prevent soft resets due to accidentally hitting RUN and SEL at the same time, set <a href="#pce.disable_softreset">pce.disable_softreset</a> to <b>1</b>.  This will prevent the emulated PCE from seeing both of those buttons pressed at the
  same time.  However, it is not guaranteed to work on all games, particularly ones with sloppily-coded gamepad polling routines.
 </p>
 <?php EndSection(); ?>

 <?php BeginSection('Sprite Flickering', 'Section_advanced_spritelimit'); ?>
 <p>
  Sprite flickering in shmups got you down?  Tired of scenery having a critical existence failure in games that have complex multi-layer effects?  Then the <a href="#pce.nospritelimit">pce.nospritelimit</a> setting is for you!<br>
  Changing this setting to a value of <b>1</b> will eliminate 99% of your flickering and existence failure woes.  Side effects may include the superpower of seeing submarines through water(as in the first boss
  scene of "Bloody Wolf"), along with seeing other hidden elements and graphical glitches("Ninja Ryukenden" has at least one broken cutscene with this setting enabled).
 </p>

 <table border>
  <tr><th colspan="2"><i>Bloody Wolf</i> (glitching example)</th><th colspan="2"><i>Ginga Fukei Densetsu Sapphire</i> (improvement example)</th></tr>
  <tr><td><img src="bwolf0.png"></td><td><img src="bwolf1.png"></td><td><img src="sapphire0.png"></td><td><img src="sapphire1.png"></td></tr>
  <tr><td>pce.nospritelimit 0</td><td>pce.nospritelimit 1</td><td>pce.nospritelimit 0</td><td>pce.nospritelimit 1</td></tr>
 </table>

 <?php EndSection(); ?>

 <?php BeginSection('Obnoxious Sound Effects in CD Games', 'Section_cdvolbalance'); ?>
 <p>
  Many CD games have awesome music, but it is drowned out by excessively loud obnoxious sound effects.  This can be partially remedied by altering the <a href="#pce.cdpsgvolume">pce.cdpsgvolume</a> and <a href="#pce.adpcmvolume">pce.adpcmvolume</a> settings, try say a value of <b>50</b>,
  but doing so may cause issues with cutscenes and PSG music-only sections.
 </p>
 <?php EndSection(); ?>

<?php EndSection(); ?>

<?php PrintSettings(); ?>

<?php EndPage(); ?>
