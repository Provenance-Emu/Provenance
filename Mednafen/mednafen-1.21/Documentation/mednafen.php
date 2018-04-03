<?php require("docgen.inc"); ?>

<?php BeginPage('', 'General'); ?>

 <?php BeginSection("Introduction", "Section_introduction"); ?>
 <p>
 This main document covers general Mednafen usage, generally regardless of which system is being emulated.  Documentation covering key assignments, settings, and related information for each system emulation module is linked to in the table of contents under "Emulation Module Documentation".
 </p>

 <p>
  The term "movie" used in this documentation refers to save-state and recorded input stream stored in a file, generally usable only in Mednafen itself.<br>
  The terms "audio/video movie", "QuickTime movie", and variations thereof refer to audio and video data recorded and stored in a file, and
  usable with external programs.
 </p>
  <?php BeginSection("Base Directory", "Section_base_directory"); ?>
   <p>
    Mednafen's "base directory" is the directory under which Mednafen stores its data and
    looks for various auxillary data by default.  If the "<b>HOME</b>" environment variable is set, it will be suffixed with "/.mednafen"
    and used as the base directory(in other words ~/.mednafen, or $HOME/.mednafen).  If the "<b>MEDNAFEN_HOME</b>" environment variable is set,
    it will be used as the base directory.  If neither the "HOME" nor "MEDNAFEN_HOME" environment
    variable is set, and the current user has an entry in the password file, the corresponding home directory
    will be used as if it were the "HOME" environment variable.
   </p>

   <p>
    On Microsoft Windows, these conditions are typically
    not met, in which case the directory the Mednafen executable("mednafen.exe") is in will be used as the base directory.
   </p>

   <p>
    If none of the preceding conditions were met, then you're doomed, doomy doomy DOOMED, GOTO DOOM.
   </p>

  <?php EndSection(); ?>

 <?php EndSection(); ?>

 <?php BeginSection("Core Features", "Section_core_features"); ?>
 <ul>
  <li>Physical joystick/gamepad support.</li>
  <li>Versatile input configuration system; assign multiple physical buttons to a virtual button or action.</li>
  <li>Multiple graphics filters and scaling modes.</li>
  <li>Save states.</li>
  <li>Real-time game rewinding.</li>
  <li>Screen snapshots, saved in PNG format.</li>
  <li>QuickTime movie recording.</li>
  <li>MS WAV-format sound logging.</li>
  <li>Loading games from gzip and (pk)zip compressed archives.</li>
  <li>Network play(utilizing an external dedicated server program).</li>
</ul>

 <?php BeginSection("CD Emulation", "Section_cdrom_emulation"); ?>
 <p>
  Mednafen can load CD-ROM games from a dumped copy of the disc, such as CUE+BIN.  Physical CD support was removed in version 0.9.38.
 </p>

<?php BeginSection("Compact Disc Images", "Section_cd_images"); ?>
 <p>
  Mednafen supports "CUE" sheets, CloneCD "CCD/IMG/SUB", and cdrdao "TOC" files; though only a very limited
  subset of the latter's full capabilities is supported.  Mednafen supports raw, simple storage formats supported by
  <a href="http://www.mega-nerd.com/libsndfile/">libsndfile</a>(MS WAV, AIFF/AIFC, AU/SND, etc.), and <a href="http://xiph.org/vorbis/">Ogg Vorbis</a> and <a href="http://www.musepack.net/">Musepack</a> audio files referenced by CUE sheets.
  MP3 is not supported, and will not be supported.
 </p>
 <p>
  The cdrdao "TOC" support in Mednafen includes support for "RW_RAW" subchannel data, needed for CD+G.  Note that Mednafen assumes that the Q subchannel
  is also included in the RW_RAW data area in the disc image(even though the name "RW_RAW" would suggest it isn't present, cdrdao seems to included it).  If
  the Q subchannel data is missing from the RW_RAW data area in the disc image, Mednafen's CD emulation will not work properly.
 </p>
 <p>
  Since 0.8.4, Mednafen will perform simple data correction on disc images that contain EDC and L-EC data(2352-byte-per-sector "raw").
  It calculates the real EDC, and if it doesn't match the EDC recorded for that sector, it will evaluate the L-EC data to repair the data.  If the
  data is unrepairable, an error message will be displayed.
  <br>
  <b>This may cause problems with naive patches that don't update the error-correction data(at least the 32-bit EDC, if that's correct, the L-EC data will
  be ignored)!</b>
 </p>
 <p>
  Enabling the <a href="#cd.image_memcache">cd.image_memcache</a> option is recommended in many situations; read the setting description
  for more details.<br><b>CAUTION:</b> When using a 32-bit build of Mednafen on Windows or a 32-bit operating system, Mednafen may run out of address
  space(and error out, possibly in the middle of emulation) if this option is enabled when loading large disc sets(e.g. 3+ discs) via M3U files.
 </p>
<?php EndSection(); ?>

<?php BeginSection("Multiple-CD Games", "Section_multicd_games"); ?>
 <p>
  To play a game that consists of more than one CD, you will need to create an
  M3U file(plain-text, ".m3u" extension), and enter the filenames of the CUE/TOC/CCD files, one per line.  Load the M3U file
  with Mednafen instead of the CUE/TOC/CCD files, and use the F6 and F8 keys to switch among the various discs available.
  <br>
  <b>Note:</b> Preferably, your M3U file(s) should reference CUE/TOC/CCD files that are in the same directory as the M3U file,
  otherwise you will likely need to alter the <a href="#filesys.untrusted_fip_check">filesys.untrusted_fip_check</a> setting.
 </p>
 <?php EndSection(); ?>

 <?php BeginSection("CD+G", "Section_cdg"); ?>
  Both the <a href="pce.html">PC Engine (CD)</a> and <a href="pcfx.html">PC-FX</a> emulation modules support CD+G playback; however,
  the PC-FX BIOS doesn't appear to be as resilient when dealing with scratched discs/damaged data as the PC Engine CD BIOS is.
  <br><br>
  <b>Note:</b> CD+G graphics data is stored in the R-W subchannel data of discs.  You must use a disc image format that includes this
  data(such as in the cdrdao TOC or CloneCD formats; CUE format definitely isn't going to work).
 <?php EndSection(); ?>

 <?php BeginSection("PhotoCD Portfolio", "Section_photocdportfolio"); ?>
  The <a href="pcfx.html">PC-FX</a> emulation module supports low-resolution single-session Kodak "PhotoCD Portfolio" disc playback.
  Hardware features to support multi-session CDs are not fully emulated; they may or may not work.
 <?php EndSection(); ?>

 <?php EndSection(); ?>

 <?php EndSection(); ?>

 <?php BeginSection("Security Issues", "Section_security"); ?>

 This section discusses various known design flaws/choices, bugs, and limitations in Mednafen that have security implications.

 <?php BeginSection("Save States", "Section_security_savestates"); ?>
 Causing Mednafen to lock-up, abort, or consume large amounts of CPU time via loading a specially-constructed save state is
 a trivial exercise.  It is hypothetically possible to overflow some buffers on some emulated systems by clever
 manipulation of saved timekeeping variables.  In combination with custom emulated machine code and state, it may therefore
 be possible to run arbitrary host code, compromising the host system. <b>Therefore, loading save states from parties
 you have reason to distrust, or not trust, is advised against.</b>
 <?php EndSection(); ?>

 <?php BeginSection("CD images and PSF(PSF1, GSF, etc.) Files", "Section_security_includes"); ?>
 <p>
 CUE and TOC, and PSF(PSF1, GSF, etc.) files can reference arbitrary files for inclusion and parsing.  Inclusion of
 device files may cause odd system behavior, particularly if you are running Mednafen as root(which you shouldn't be!) on a
 UN*X system, or cause Mednafen to lockup or abort.  <b>In combination with save states, this file inclusion presents
 the possibility of leaking of private local information;</b> for example, if an attacker supplies a CD image or PSF rip that
 you subsequently run, and can convince you to save a state and send it back, or to connect to a network play server(in
 which save states are automatically utilized), the attacker may then have access to local private data from your
 system.  The setting <a href="#filesys.untrusted_fip_check">filesys.untrusted_fip_check</a>, when set to 1(the default), will enable
 checks that mitigate this potential problem.
 </p>
 <?php EndSection(); ?>

 <?php BeginSection("Network Play", "Section_security_netplay"); ?>
 <p>
 Mednafen's network play automatically utilizes save states to synchronize state among newly connected players, and
 thereafter at connected players' command.  Hence, any security issues relating to save states apply to network play as well.
 </p>

 <p>
 Additionally, network problems, or a malicious network play server or player, may cause Mednafen to lock up or consume large
 amounts of CPU time processing received data.
 </p>
 <?php EndSection(); ?>

 <?php EndSection(); ?>

 <?php BeginSection("Using Mednafen", "Section_using"); ?>
 <p>
 
 </p>
 <?php BeginSection("Key Assignments", "Section_key_assignments"); ?>
 <p>
  All default key mappings are by scancode, so you'll need to press the keys corresponding to the appropriate positions on the standard U.S keyboard layout.
 </p>
 <p>
 </p>
 <table border>
 <tr><th>Key(s):</th><th>Action:</th><th>Configuration String:</th></tr>
 <tr><td>F1</td><td><a name="command.toggle_help">Toggle in-game quick help screen.</a></td><td>toggle_help</td></tr>
 <tr><td>F5</td><td><a name="command.save_state">Save state.</a></td><td>save_state</td></tr>
 <tr><td>F7</td><td><a name="command.load_state">Load state.</a></td><td>load_state</td></tr>
 <tr><td>0-9</td><td>Select save state slot.</td><td>"0" through "9"</td></tr>
 <tr><td>-</td><td><a name="command.state_slot_dec">Decrement selected save state slot.</a></td><td>state_slot_dec</td></tr>
 <tr><td>=</td><td><a name="command.state_slot_inc">Increment selected save state slot.</a></td><td>state_slot_inc</td></tr>
 <tr><td>ALT&nbsp;+&nbsp;S</td><td>Toggle <a href="#srwframes">600-frame</a> save-state rewinding functionality, disabled by default.</td><td>toggle_state_rewind</td></tr>
 <tr><td>SHIFT + F5</td><td>Record movie.</td><td>save_movie</td></tr>
 <tr><td>SHIFT + F7</td><td>Play movie.</td><td>load_movie</td></tr>
 <tr><td>SHIFT + 0-9</td><td>Select movie slot.</td><td>"m0" through "m9"</td></tr>
 <tr><td>LALT&nbsp;+&nbsp;C</td><td>Toggle cheat console.<br><b>Note</b>: Will not respond to RALT/AltGr even if remapped.</td><td>togglecheatview</td></tr>
 <tr><td>ALT&nbsp;+&nbsp;T</td><td>Toggle cheats active.</td><td>togglecheatactive</td></tr>
 <tr><td>T</td><td>Enable network play console input.</td><td>togglenetview</td></tr>
 <tr><td>LALT&nbsp;+&nbsp;D</td><td>Toggle debugger.<br><b>Note</b>: Will not respond to RALT/AltGr even if remapped.</td><td>toggle_debugger</td></tr>
 <tr><th>Key(s):</th><th>Action:</th><th>Configuration String:</th></tr>
 <tr><td>`</td><td>Fast-forward.</td><td>fast_forward</td></tr>
 <tr><td>\</td><td>Slow-forward.</td><td>slow_forward</td></tr>
 <tr><td>ALT&nbsp;+&nbsp;A</td><td><a name="command.advance_frame">Enter frame advance mode, or advance the frame if already in it.</a></td><td>advance_frame</td></tr>
 <tr><td>ALT&nbsp;+&nbsp;R</td><td><a name="command.run_normal">Exit frame advance mode.</a></td><td>run_normal</td></tr>
 <tr><td>Pause</td><td><a name="command.pause">Pause/Unpause.</a></td><td>pause</td></tr>
 <tr><td>SHIFT + F1</td><td>Toggle frames-per-second display(from top to bottom, the display format is: virtual, rendered, blitted).</td><td>toggle_fps_view</td></tr>
 <tr><td>Backspace</td><td>Rewind emulation, if save-state rewinding functionality is enabled, up to <a href="#srwframes">600 frames</a>.</td><td>state_rewind</td></tr>
 <tr><td>F9</td><td>Save (rawish) screen snapshot.</td><td>take_snapshot</td></tr>
 <tr><td>SHIFT + F9</td><td>Save screen snapshot, taken after all scaling and special filters/shaders are applied.</td><td>take_scaled_snapshot</td></tr>
 <tr><td>ALT&nbsp;+&nbsp;O</td><td>Rotate the screen</td><td>rotate_screen</td></tr>
 <tr><td>ALT + Enter</td><td>Toggle fullscreen mode.</td><td>toggle_fs</td></tr>
 <tr><td nowrap>CTRL + 1<br>through<br>Ctrl + 9</td><td>Toggle layer.</td><td>"tl1" through "tl9"</td></tr>
 <tr><th>Key(s):</th><th>Action:</th><th>Configuration String:</th></tr>
 <tr><td>F3</td><td><a name="command.input_config_abd"><a href="#Section_analog_detection">Detect analog buttons</a> on physical joysticks/gamepads(for use with the input configuration process).</a></td><td>input_config_abd</td></tr>
 <tr><td nowrap>ALT + SHIFT + [<i>n</i>]</td><td>Configure buttons for emulated device on input port <i>n</i>(1-8).</td><td>input_config<i>n</i></td></tr>
 <tr><td nowrap>CTRL + SHIFT + [<i>n</i>]</td><td>Select input device on input port <i>n</i>(1-8).<br /><br /><b>Note:</b> Many games do not expect input devices to change while the game is running, and thus may require a hard reset.</td><td>device_select<i>n</i></td></tr>
 <tr><td>F2</td><td><a name="command.input_configc">Activate in-game input configuration process for a command key.</a></td><td>input_configc</td></tr>
 <tr><td>SHIFT + F2</td><td>Like F2, but after configuration completes, to activate the configured command key will require all buttons configured to it to be in a pressed state simultaneously to trigger the action.  Note that keyboard modifier keys(CTRL, ALT, SHIFT) are still treated as modifiers and not discrete keys.<br><br>Especially useful in conjunction with the <a href="#ckdelay">ckdelay</a> setting.</td><td>input_configc_am</td></tr>
 <tr><td nowrap>CTRL + SHIFT + Menu</td><td><a name="command.toggle_grab">Toggle <a href="#Section_input_grabbing">input grabbing</a>(for emulated mice and keyboards).</a></td><td>toggle_grab</td></tr>
 <tr><th>Key(s):</th><th>Action:</th><th>Configuration String:</th></tr>
 <tr><td>F10</td><td>Reset.</td><td>reset</td></tr>
 <tr><td>F11</td><td>Hard reset(toggle power switch).</td><td>power</td></tr>
 <tr><td>Escape/F12</td><td>Exit(the emulator, or netplay chat mode).</td><td>exit</td></tr>
 </table>

 <?php EndSection(); ?>

 <?php BeginSection("Input Grabbing", "Section_input_grabbing"); ?>
 <p>
 Keyboard and mouse input can be grabbed(from the OS/window manager) by pressing <a href="#command.toggle_grab">CTRL+SHIFT+Menu</a>(default mapping), and disabled by pressing the same again.
 </p>
 <p>
  Emulated keyboards will only function when input grabbing is enabled.  When input grabbing is enabled, and at least one emulated keyboard that has an emulated key mapped
  to a host keyboard key is enabled, all(except for the input grab toggling mapping) other host keyboard input mappings will see all keyboard keys as being unpressed.  In
  other words, this disables hotkeys/command keys(unless the user has mapped them to a non-keyboard device), and the keyboard mappings of any non-keyboard emulated devices.
 </p>

 <p>
  Emulated mice mapped to the system mouse will only function properly when input grabbing is enabled or when in a fullscreen video mode, the debugger is inactive, and no
  other emulated input devices that rely on absolute mouse coordinates(e.g. lightguns) are active and mapped to the system mouse.
 </p>
 <?php EndSection(); ?>

 <?php BeginSection("Remapping Buttons and Keys", "Section_remapping_input"); ?>
  <p>
   You may configure a virtual(emulated) input device by using special command keys in Mednafen while a game is running.
  </p>
  <p>
   <a name="Section_analog_detection"></a>
   <font color="yellow"><b><u>Caution:</u></b></font>  Users of XBox 360-type/compatible controllers on operating systems other than Microsoft Windows(e.g. Linux), or users of other
   controllers with analog buttons, should complete the following process before attempting any configuration that will map a physical analog button to a virtual input.
   Failure to complete this process under the aforementioned conditions which necessitate it will result in the input configuration functionality becoming confused, and the
   resulting input mappings will be wonky.<br>
   <blockquote>
    Twirl all sticks and D-pads, move all throttles to maximum then center(and leave them there), and press all analog buttons on any physical gamepads/joysticks
    with analog buttons you want to use in the input configuration process, then press <a href="#command.input_config_abd">F3</a>. Then, configure input as
    normal. The detected analog buttons will be recognized during input configuration until Mednafen exits; if you exit Mednafen and restart, and want to
    configure input devices again, you'll need to repeat the twirling-pressing-<a href="#command.input_config_abd">F3</a> process again).
   </blockquote>
  </p>

  <p>
   All joystick throttles should be set to their center position before configuring inputs.  To register a "press" with a throttle control during the input
   configuration process, move it to the maximum or minimum position as appropriate, then back to the center position.
  </p>

  <p>
   To configure the virtual device on input port 1, press ALT+SHIFT+1.  For the virtual device on input port 2, press ALT+SHIFT+2.  Etc.
  </p>

  <p>
   After pressing the appropriate command key or command key combination, a message will be displayed at the bottom of the screen similar to "GamePad #1: A (1)".  At this time, you would press the physical joystick or keyboard button you want to map to button "A" on the first virtual gamepad.  After you push the button, you should see something like "GamePad #1: A (2)".  If you want to map any other physical buttons to virtual button "A", press them now.  Otherwise, press the physical joystick or keyboard button you pressed before, and you will move on to the configuration of the next virtual button("B").
  </p>

  <p>
   To configure a command key, press <a href="#command.input_configc">F2</a>, and then the command key whose mapping you wish to change.  The process is similar to that for a virtual input device.
  </p>
 <?php EndSection(); ?>

 <?php BeginSection("Command-line", "Section_command_line"); ?>
 <p>
  Mednafen supports options passed on the command line.   Options
  are taken in the form of "-option value".  Some options are valueless.
 </p>
 <p>
  In addition to the options listed in the table below, any setting listed in the "Settings" section of this document and any system emulation module sub-document can be set by prefixing it with
  a hyphen(-), followed by the value, such as: -nes.slstart 8
</p>
  <table border>
   <tr><th>Option:</th><th>Value Type:</th><th>Description:</th></tr>
   <tr><td nowrap>-force_module x</td><td>string</td><td>Force usage of specified emulation module.</td></tr>
   <tr><td nowrap>-which_medium x</td><td>integer</td><td>Start with specified disk/CD(numbered from 0) inserted.  For ejected, pass -1.</td></tr>
   <tr><td>-connect</td><td><i>(n/a)</i></td><td>Trigger to connect to remote host after the game is loaded.</td></tr>
   <tr><td nowrap>-soundrecord x</td><td>string</td><td>Record sound output to the specified filename in the MS WAV format.</td></tr>
   <tr><td nowrap>-qtrecord x</td><td>string</td><td>Record video and audio output to the specified filename in the QuickTime format.</td></tr>
  </table>
 <?php EndSection(); ?>

<?php BeginSection("Configuration Files", "Section_config_files"); ?>
 <p>
  Mednafen loads/saves its settings from/to a primary configuration file, named "<b>mednafen.cfg</b>", under the Mednafen
  <a href="#Section_base_directory">base directory</a>.  This file is created and written to when Mednafen shuts down.
 </p>
 <p>
  Mednafen loads override settings from optional per-module override configuration files, also located directly under the
  Mednafen <a href="#Section_base_directory">base directory</a>.  The general pattern for the naming of these user-created
  files is "&lt;<b>system</b>&gt;<b>.cfg</b>"; e.g. "<b>nes.cfg</b>", "<b>pce.cfg</b>", "<b>gba.cfg</b>", "<b>psx.cfg</b>", etc.  This allows for overriding global settings
  on a per-module basis.
 </p>

 <p>
  Per-game override configuration files are also supported.  They should be placed in the <a href="#filesys.path_pgconfig"><b>pgconfig</b></a> directory
  under the Mednafen <a href="#Section_base_directory">base directory</a>.  Name these files like &lt;<b>FileBase</b>&gt;.&lt;<b>system</b>&gt;.<b>cfg</b>; e.g.
  "<b>Lieutenant Spoon's Sing-a-Tune (USA).psx.cfg</b>".
 </p>

 <p>
  The aforementioned per-module and per-game configuration override files will <b>NOT</b> be written to by Mednafen, and they will generally not
  alter the contents of the primary configuration file, unless a user action occurs that causes new setting values to be generated
  based on the current active setting value(such as toggling full-screen mode inside the emulator, for instance).  Some settings
  currently cannot be overridden properly:
  <ul>
   <li>cd.image_memcache</li>
   <li>filesys.untrusted_fip_check</li>
   <li>&lt;system&gt;.enable</li>
  </ul>
 </p>
<?php EndSection(); ?>


<?php PrintSettings("Global Settings Reference"); ?>

 <?php BeginSection("Firmware/BIOS", "Section_firmware_bios"); ?>
<p>
Some emulation modules require firmware/BIOS images to function.  If a firmware path is non-absolute(doesn't begin with
C:\ or / or similar), Mednafen will try to load the file relative to the "firmware" directory under the Mednafen <a href="#Section_base_directory">base directory</a>.  If it doesn't find it there, it will be loaded relative to the Mednafen <a href="#Section_base_directory">base directory</a> itself.  Of course,
if the "path_firmware" setting is set to a custom value, the firmware files will be searched relative to that path.
</p>
 <?php EndSection(); ?>

 <?php BeginSection("Custom Palettes", "Section_custom_palettes"); ?>
<p>
Custom palettes for a system should generally(with caveats; refer to the table near the end of this section) be named &lt;system&gt;.pal, IE "snes.pal", "pce.pal", etc., and placed in the
"palettes" directory beneath the Mednafen <a href="#Section_base_directory">base directory</a>.
</p>
<p>
Per-game custom palettes are also supported, and should be
named as &lt;FileBase&gt;.pal or &lt;FileBase&gt;.&lt;MD5 Hash&gt;.pal, IE "Mega Man 4.pal" or "Mega Man 4.db45eb9413964295adb8d1da961807cc.pal".
</p>
<p>
Each entry in a custom palette file consists of 3 8-bit color components; Red, Green, Blue, in that order.
</p>
<p>
Not all emulated systems support custom palettes.  Refer to the following list:
<?php PrintCustomPalettes(); ?>
</p>
 <?php EndSection(); ?>

 <?php BeginSection("Automatic IPS Patching", "Section_ips_patching"); ?>
 <p>
        Place the IPS file in the same directory as the file to load,
        and name it &lt;FullFileName&gt;.ips.
        <pre>
        Examples:       Boat.nes - Boat.nes.ips
                        Boat.zip - Boat.zip.ips
                        Boat.nes.gz - Boat.nes.gz.ips
                        Boat     - Boat.ips
        </pre>
 </p>
 <p>
  Some operating systems and environments will hide file extensions. Keep this in mind if you are having trouble.
 </p>
 <p>
        Patching is applied in a file format-agnostic way; however, dynamic patching is not done with CD images, nor with
	firmware.
 </p>
 <?php EndSection(); ?>
 
 <?php EndSection(); ?>

 <?php BeginSection("Advanced Usage", "Section_advanced"); ?>
  <?php BeginSection("Minimizing video/audio/input Lag", "Section_lag"); ?>
This section is a work-in-progress, tips given may not cover all cases, latency reduction is a black art on modern
PCs, etc etc.
<p>
Miscellaneous relevant external links:
<ul>
 <li><a href="http://www.ouma.jp/ootake/delay-solution.html">http://www.ouma.jp/ootake/delay-solution.html</a></li>
 <li><a href="http://www.ouma.jp/ootake/delay-win7vista.html">http://www.ouma.jp/ootake/delay-win7vista.html</a></li>
 <li><a href="http://www.tftcentral.co.uk/articles/input_lag.htm">TFT Central - Input Lag Testing</a></li>
 <li><a href="http://www.prad.de/en/monitore/specials/inputlag/inputlag.html">An investigation of the test process used to date for determining the response time of an LCD monitor, known as input lag</a></li>
 <li><a href="http://shoryuken.com/forum/index.php?threads/sub-1-frame-hdtv-monitor-input-lag-database.145141/">Sub 1 frame HDTV/Monitor Input Lag Database</a></li>
 <li><a href="http://www.tomshardware.com/reviews/s242hl-bid-u2412m-t24a550,3016-14.html">http://www.tomshardware.com/reviews/s242hl-bid-u2412m-t24a550,3016-14.html</a></li>
 <li><a href="http://www.tomshardware.com/reviews/ultrasharp-u2711-ds-277w-multisync-pa271w,2968-14.html">http://www.tomshardware.com/reviews/ultrasharp-u2711-ds-277w-multisync-pa271w,2968-14.html</a></li>
</ul>
</p>
   <?php BeginSection("Hardware Selection", "Section_lag_hardware"); ?>
    <ul>
    <li><u><b>Video Card:</b></u><blockquote>Higher-performing discrete video cards are preferable, but anything with similar
or better OpenGL performance to an NVidia GeForce 9500GT should be fine.</blockquote></li>
    <li><u><b>Monitor:</b></u><blockquote>Choose a monitor with the lowest input lag(AKA display lag), as well as as a low response time(though response time isn't as an important metric to consider, since it's usually acceptably small on modern end-user PC monitors).
Unfortunately, monitor input/display lag is not typically specified by the manufacturer, and it can even vary between
different revisions of the same "model".<br>A monitor capable of 120Hz vertical refresh rate operation, and that also has a low
average input lag(<16ms), would be ideal.
<p>
Keep in mind that sometimes the "game mode" of a modern monitor(or TV) must be selected in order for minimum monitor input lag.
</p>
<p>
For the lowest possible video lag, however, obtain and use an old CRT monitor, and set up a video mode with a vertical
refresh rate of at least 120Hz.
</p>
</blockquote></li>
    <li><u><b>Sound Card:</b></u>  <i>(To be written)</i></li>
   </ul>
   <?php EndSection(); ?>

   <p>

   </p>
   <?php BeginSection("Settings to Minimize Video Lag", "Section_minimize_video_lag"); ?>
   <a name="Core+Features%01Advanced+Usage%01Minimizing+video%2Faudio%2Finput+Lag%01Settings+to+Minimize+Video+Lag"></a>
    <p>
    Disabling vsync can also help to reduce keyboard and mouse input lag to a degree, due to the design of common GUI environments and SDL.
    </p>
    <table border="1">
     <tr><th>Mednafen setting name:</th><th>Value for maximum lag reduction:</th></tr>
     <tr><td><a href="#video.driver">video.driver</a></td><td>opengl</td></tr>
     <tr><td><a href="#video.glvsync">video.glvsync</a></td><td>0</td></tr>
     <tr><td><a href="#video.blit_timesync">video.blit_timesync</a></td><td>0</td></tr>
    </table>
    <p>
     <u>Operating System:</u> Disable vsync and triple-buffering if enabled via your card driver's setting utility or control panel.
    </p>
    <p>
     <u>Operating System:</u> Set the "max frames to render ahead"(NVidia) or "flip queue size"(AMD/ATI) to "0"(zero) in your video card
	driver's setting utility or control panel(mostly a Windows-specific tip; TODO: verify that it is relevant for OpenGL).
    </p>
    <p>
     <u>Operating System:</u> Disable window/desktop compositor("Aero" on Windows Vista and newer).
    </p>
    <p>
     <u>Mednafen:</u> Choose full-screen resolutions, via the <a href="#&lt;system&gt;.xres">x-resolution</a> and
<a href="#&lt;system&gt;.yres">y-resolution</a> settings, that match your monitor's native resolution(assuming it has
a native resolution).
    </p>
    <p>
     <u>Mednafen:</u> Avoid using special video filters and scalers(hq2x, 2xsai, scale2x, temporal blur, etc.) in Mednafen.  Mednafen's simple pixel shaders are ok, provided you have a decent video card as specified in the
     hardware selection section above.
    </p>
   <?php EndSection(); ?>

   <?php BeginSection("Settings to Minimize Audio Lag", "Section_minimize_audio_lag"); ?>
<p>
<u>Mednafen:</u> Select a <a href="#sound.driver">sound driver</a> that is closer to the actual hardware, such as "alsa" on Linux, "oss" on other UN*X platforms, and "wasapi" on Windows Vista and newer.  If you choose to use "OSS", heed the advice regarding osscore.conf and max_intrate.
</p>
<p>
<u>Mednafen:</u> Select a <a href="#sound.device">sound device</a> that is closest to the actual hardware; IE "hw:0", "hw:1", "hw:2", etc. on ALSA.<br>
Avoid selecting a higher-level sound device that is routed through a sound server like PulseAudio!
</p>
<p>
<u>Mednafen:</u> Select a <a href="#sound.buffer_time">sound buffer size</a> that is as small as possible without causing excessive crackling
or speed issues(20ms should be a fairly safe setting with ALSA on a modern multi-core CPU system).
</p>
<p>
<u>Mednafen:</u> Optionally set the <a href="#sound.period_time">sound period size</a> setting to 500(microseconds).
<br><b>Note:</b> The system sound card driver may not handle a value this small correctly,
and may cause sound card or system malfunctions.  Additionally, the system sound card driver may constrain the
sound buffer size to an unusably small value.
</p>
<p>
<u>Mednafen:</u> Set the <a href="#sound.rate">sound rate</a> setting to your sound card's native playback rate, IE the rate which
has the minimum amount of processing done to it before being passed to the DAC or digital output.  This tends to be
"192000" or "96000" on modern sound cards, "48000" on older(late 1990s, early 2000s), and "44100" on older still(early to mid 1990s).  If you don't know, just leave it at the default of "48000".
</p>
<p>
<u>Operating System:</u> Disable 3D spatialization, equalizer, and other special effects via your sound card driver's setting utility or control panel, if applicable.
</p>


   <?php EndSection(); ?>

  <?php EndSection(); ?>

  <?php BeginSection("Input Mapping Settings Format", "Section_input_mapping_format"); ?>
<p>
The general format of an input mapping is: <b><u>DEVICE_TYPE</u></b> <b><u>DEVICE_ID</u></b> <b><u>DEVICE_INPUT</u></b> [<b><u>SCALE</u></b>] [<b><u>LOGIC</u></b>] [...]
</p>
<p><b><u>DEVICE_TYPE</u></b> is one of "<a href="#Section_ims_keyboard">keyboard</a>", "<a href="#Section_ims_mouse">mouse</a>", or "<a href="#Section_ims_joystick">joystick</a>".</p>
<p><b><u>DEVICE_ID</u></b> is the ID Mednafen uses for the device to differentiate it from other devices of the same type.  Currently, only "0x0" is allowed for the "keyboard" and "mouse" <b><u>DEVICE_TYPE</u></b>.  The IDs Mednafen uses for the "joystick" type are printed to stdout on startup, like so:
<blockquote>
<pre>
 Initializing joysticks...
  ID: 0x00030428400101000002000a00000000 - Gravis GamePad Pro USB 
  ID: 0x00030e8f000301100007000c00000000 - GreenAsia Inc.    USB Joystick     
  ID: 0x0003046dc21e20200008000b00000000 - Generic X-Box pad
  ID: 0x0003045e003801100006000800000000 - Microsoft SideWinder Precision 2 Joystick
  ID: 0x00030428400101000002000a00000001 - Gravis GamePad Pro USB 
  ID: 0x0003046dc21a01100002000a00000000 - Logitech Logitech(R) Precision(TM) Gamepad
  ID: 0x0003045e020201000008000a00000000 - Microsoft X-Box pad v1 (US)
  ID: 0x00140007000101000002000a00000000 - Microsoft SideWinder GamePad
  ID: 0x00140007000101000002000a00000001 - Microsoft SideWinder GamePad
  ID: 0x00140007000101000002000a00000002 - Microsoft SideWinder GamePad
</pre>
</blockquote>
</p>
<p><b><u>DEVICE_INPUT</u></b> is a string, without any whitespace inside, specific to the device type being used.</p>
<p><b><u>SCALE</u></b> is an optional integer between 0-65535, representing a 4.12 fixed-point quantity used to scale analog(e.g. axis) inputs in most usage contexts.  The default is 4096(equivalent to 1.0).</p>
<p><b><u>LOGIC</u></b> is an optional string, "||" or "&&" or "&!", specifying a boolean operation, OR and AND and AND NOT respectively, used to join multiple physical input specifications together.  Evaluated left to right, with "&&" and "&!" having the same higher precedence over "||".  The exact behavior and semantics when used with a virtual input that expects an analog value is currently unspecified and may be subject to change, but will generally allow control from any of the specified physical inputs when they are manipulated individually.

   <?php BeginSection("Keyboard", "Section_ims_keyboard"); ?>
<b><u>SCANCODE</u></b>[<b><u>MODIFIER</u></b>]...<br>
<p><b>Modifiers:</b> (only valid with command key mappings)
<ul>
 <li>+ctrl</li>
 <li>+alt</li>
 <li>+shift</u></b>
</ul></p>
   <?php EndSection(); ?>

   <?php BeginSection("Mouse", "Section_ims_mouse"); ?>
<ul>
 <li>(cursor|rel)_(x|y)(-|+|-+|+-)</li>
 <li>button_(left|middle|right|x1|x2|0| ... |31)</li>
</ul>
   <?php EndSection(); ?>

   <?php BeginSection("Joystick", "Section_ims_joystick"); ?>
When manually mapping the axes of an emulated lightgun to the axes of a physical lightgun that presents itself as a joystick device, use
the optional "g" flag with "-+" polarity(e.g. "abs_0-+g").
<ul>
 <li>abs_(0| ... |1023)(-|+|-+|+-)[g]</li>
 <li>button_(0| ... |1023)</li>
</ul>
   <?php EndSection(); ?>

  <?php EndSection(); ?>
 <?php EndSection(); ?>

 <?php BeginSection("Troubleshooting and Common Solutions", "Section_troubleshooting"); ?>
  <p>
   When Mednafen encounters a fatal error, it will print details of the error to stdout and/or stderr before exiting.  On the Microsoft Windows builds of Mednafen,
   when Mednafen is not being run from a console, stdout and stderr are redirected to files "<b>stdout.txt</b>" and "<b>stderr.txt</b>", respectively.
  </p>
  <?php BeginSection("No sound output on Linux.", "Section_troubleshooting_nosoundlinux"); ?>
   <p>
    Due to historical Linux distribution design decisions and problems with various software audio mixing solutions on Linux, Mednafen's ALSA output code
    attempts to output to device "<b>hw:0</b>" by default.  This may cause problems if your sound card does not support hardware mixing of streams and your system is
    running another program that is monopolizing the sound device(like the PulseAudio server), or you have used multiple sound cards.
   </p>
   <p>
    For the case of PulseAudio, you can utilize the <a href="http://linux.die.net/man/1/pasuspender">pasuspender</a> tool, or set the <a href="#sound.device">sound.device</a> setting to
    "<b>sexyal-literal-default</b>" to try to use PulseAudio through ALSA(assuming your distribution has things configured properly); the use of pasuspender
    is the recommended option.
   </p>
   <p>
    For the case of multiple sound cards, select a different "<b>hw:?</b>" device, where <b>?</b> is an integer representing the device number/index(check the contents of file "<b>/proc/asound/cards</b>").
   </p>
  <?php EndSection(); ?>

  <?php BeginSection("Configuration file is a mess in Notepad in Windows.", "Section_troubleshooting_configcrlf"); ?>
   <p>
    Mednafen's settings file currently uses UN*X-style line breaks, which Notepad does not handle very well.  Use
    <a href="http://notepad-plus-plus.org/">Notepad++</a> instead.
   </p>
  <?php EndSection(); ?>
 <?php EndSection(); ?>

 <?php DoModDocLinks(); ?>

 <?php /*ExternalSection("Cheat Guide", "cheat.html"); */?>
 <?php ExternalSection("Debugger", "debugger.html"); ?>
 <?php ExternalSection("Network Play", "netplay.html"); ?>

 <?php BeginSection("Licenses, Copyright Notices, and Code Credits", "Section_legal"); ?>
 <p>
  Mednafen makes use of much open-source code from other people, and could not be what it is without their work.  Feel
  free to give them your thanks, but keep in mind most have nothing to do with the Mednafen project, so don't ask
  them questions regarding Mednafen unless appropriate in context.
 </p>
 <p>
 In addition to the listing of licenses and copyright notices for code included in Mednafen, the following 
 "non-system" external libraries are linked to:
 <ul>
  <li><a href="http://www.mega-nerd.com/libsndfile/">libsndfile</a></li>
  <li><a href="http://www.libsdl.org/">SDL</a></li>
  <li><a href="http://www.zlib.org">zlib</a></li>
 </ul>
 </p>
 <hr>

 <p>
  <?php BeginSection("libmpcdec", "Section_legal_libmpcdec", "http://www.musepack.net/"); ?>
  <blockquote>
  <pre>
  Copyright (c) 2005-2009, The Musepack Development Team
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are
  met:

  * Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.

  * Redistributions in binary form must reproduce the above
  copyright notice, this list of conditions and the following
  disclaimer in the documentation and/or other materials provided
  with the distribution.

  * Neither the name of the The Musepack Development Team nor the
  names of its contributors may be used to endorse or promote
  products derived from this software without specific prior
  written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
  </pre>
  </blockquote>
  <?php EndSection(); ?>

  <?php BeginSection("Tremor", "Section_legal_tremor", "http://xiph.org/"); ?>
  <blockquote>
<pre>
Copyright (c) 2002, Xiph.org Foundation

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

- Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

- Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

- Neither the name of the Xiph.org Foundation nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
</pre>
  </blockquote>
  <?php EndSection(); ?>

 <?php BeginSection("Gb_Snd_Emu", "Section_legal_gb_snd_emu", "http://slack.net/~ant/libs/audio.html"); ?>
<blockquote>
<pre>
/* Library Copyright (C) 2003-2004 Shay Green. Gb_Snd_Emu is free
software; you can redistribute it and/or modify it under the terms of the
GNU General Public License as published by the Free Software Foundation;
either version 2 of the License, or (at your option) any later version.
Gb_Snd_Emu is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
more details. You should have received a copy of the GNU General Public
License along with Gb_Snd_Emu; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA */
</pre>
</blockquote>
 <?php EndSection(); ?>

<?php BeginSection("Blip_Buffer", "Section_legal_blip_buffer", "http://www.slack.net/~ant/libs/"); ?>
<blockquote>
<pre>
Copyright (C) 2003-2006 Shay Green. This module is free software; you
can redistribute it and/or modify it under the terms of the GNU Lesser
General Public License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version. This
module is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for
more details. You should have received a copy of the GNU Lesser General
Public License along with this module; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
</pre>
</blockquote>
 <?php EndSection(); ?>

 <?php BeginSection("Sms_Snd_Emu(base for T6W28_Apu NGP code)", "Section_legal_sms_snd_emu", "http://slack.net/~ant/libs/audio.html"); ?>
<blockquote>
<pre>
Copyright (C) 2003-2006 Shay Green. This module is free software; you
can redistribute it and/or modify it under the terms of the GNU Lesser
General Public License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version. This
module is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for
more details. You should have received a copy of the GNU Lesser General
Public License along with this module; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
</pre>
</blockquote>
 <?php EndSection(); ?>

<?php BeginSection("Handy", "Section_legal_handy", "http://handy.sourceforge.net/"); ?>
<blockquote>
<pre>
Copyright (c) 2004 K. Wilkins

This software is provided 'as-is', without any express or implied warranty.
In no event will the authors be held liable for any damages arising from
the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.

2. Altered source versions must be plainly marked as such, and must not
   be misrepresented as being the original software.

3. This notice may not be removed or altered from any source distribution.
</pre>
</blockquote>
 <?php EndSection(); ?>

 <?php BeginSection("PC2e (Used in portions of PC Engine CD emulation)", "Section_legal_pc2e"); ?>
<blockquote>
<pre>
        Copyright (C) 2004 Ki

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
</pre>
</blockquote>
 <?php EndSection(); ?>

 <?php BeginSection("Scale2x", "Section_legal_scale2x", "http://scale2x.sf.net/"); ?>
<blockquote>
<pre>
 * Copyright (C) 2001, 2002, 2003, 2004 Andrea Mazzoleni
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
</pre>
</blockquote>
 <?php EndSection(); ?>

<?php BeginSection("hq2x, hq3x, hq4x", "Section_legal_hqnx", "http://www.hiend3d.com/hq2x.html"); ?>
<blockquote>
<pre>
//Copyright (C) 2003 MaxSt ( maxst@hiend3d.com )

//This program is free software; you can redistribute it and/or
//modify it under the terms of the GNU Lesser General Public
//License as published by the Free Software Foundation; either
//version 2.1 of the License, or (at your option) any later version.
//
//This program is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//Lesser General Public License for more details.
//
//You should have received a copy of the GNU Lesser General Public
//License along with this program; if not, write to the Free Software
//Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
</pre>
</blockquote>
 <?php EndSection(); ?>

<?php BeginSection("nes_ntsc", "Section_legal_nes_ntsc", "http://www.slack.net/~ant/libs/ntsc.html#nes_ntsc"); ?>
<blockquote>
<pre>
/* Copyright (C) 2006 Shay Green. This module is free software; you
can redistribute it and/or modify it under the terms of the GNU Lesser
General Public License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version. This
module is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for
more details. You should have received a copy of the GNU Lesser General
Public License along with this module; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA */
</pre>
</blockquote>
 <?php EndSection(); ?>

<?php BeginSection("2xSaI", "Section_legal_2xsai"); ?>
<blockquote>
<pre>
/* 2xSaI
 * Copyright (c) Derek Liauw Kie Fa, 1999-2002
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */
/* http://lists.fedoraproject.org/pipermail/legal/2009-October/000928.html */
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("VisualBoyAdvance GameBoy and GBA code", "Section_legal_vba"); ?>
<blockquote>
<pre>
// VisualBoyAdvance - Nintendo Gameboy/GameboyAdvance (TM) emulator.
// Copyright (C) 1999-2003 Forgotten
// Copyright (C) 2004-2006 Forgotten and the VBA development team

// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2, or(at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software Foundation,
// Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
</pre>
</blockquote>
 <?php EndSection(); ?>

<?php BeginSection("trio", "Section_legal_trio", "http://daniel.haxx.se/projects/trio/"); ?>
<blockquote>
<pre>
 * Copyright (C) 1998, 2009 Bjorn Reese and Daniel Stenberg.
 * Copyright (C) 2001 Bjorn Reese <breese@users.sourceforge.net>
 * Copyright (C) 2001 Bjorn Reese and Daniel Stenberg.
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
 * MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE AUTHORS AND
 * CONTRIBUTORS ACCEPT NO RESPONSIBILITY IN ANY CONCEIVABLE MANNER.
 *
</pre>
</blockquote>

<?php EndSection(); ?>

<?php BeginSection("MD5 Hashing", "Section_legal_md5"); ?>
<blockquote>
<pre>
/*
 * RFC 1321 compliant MD5 implementation,
 * by Christophe Devine <devine@cr0.net>;
 * this program is licensed under the GPL.
 */
</pre>
</blockquote>
 <?php EndSection(); ?>

<?php BeginSection("V810 Emulator", "Section_legal_v810"); ?>
<blockquote>
<pre>
 * Copyright (C) 2006 David Tucker
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("MiniLZO", "Section_legal_minilzo", "http://www.oberhumer.com/opensource/lzo/"); ?>
<blockquote>
<pre>
   Copyright (C) 1996-2015 Markus Franz Xaver Johannes Oberhumer
   All Rights Reserved.

   The LZO library is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License as
   published by the Free Software Foundation; either version 2 of
   the License, or (at your option) any later version.

   The LZO library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with the LZO library; see the file COPYING.
   If not, write to the Free Software Foundation, Inc.,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

   Markus F.X.J. Oberhumer
   &lt;markus@oberhumer.com&gt;
   http://www.oberhumer.com/opensource/lzo/
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("Fuse Z80 emulation code", "Section_legal_fuse", "http://fuse-emulator.sourceforge.net/"); ?>
<blockquote>
<pre>
   Copyright (c) 1999-2005 Philip Kendall, Witold Filipczyk
   Copyright (c) 1999-2011 Philip Kendall

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License along
   with this program; if not, write to the Free Software Foundation, Inc.,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

   Author contact information:

   E-mail: philip-fuse@shadowmagic.org.uk
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("NeoPop Neo Geo Pocket (Color) Code", "Section_legal_neopop"); ?>
<blockquote>
<pre>
//---------------------------------------------------------------------------
// NEOPOP : Emulator as in Dreamland
//
// Copyright (c) 2001-2002 by neopop_uk
//---------------------------------------------------------------------------
//      This program is free software; you can redistribute it and/or modify
//      it under the terms of the GNU General Public License as published by
//      the Free Software Foundation; either version 2 of the License, or
//      (at your option) any later version. See also the license.txt file for
//      additional informations.
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("PC-FX MJPEG Decoding", "Section_legal_jrevdct"); ?>
<blockquote>
<pre>
/*
 * jrevdct.c
 *
 * Copyright (C) 1991, 1992, Thomas G. Lane.
 * This file is part of the Independent JPEG Group's software.
 * For conditions of distribution and use, see the accompanying README file.
 *
 */
<i>(The file is included in the Mednafen source distribution as mednafen/Documentation/README.jpeg4a)</i>
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("VRC7 Sound Emulation", "Section_legal_emu2413"); ?>
<blockquote>
<pre>
/*
YM2413 emulator written by Mitsutaka Okazaki 2001

Permission is granted to anyone to use this software for any purpose,
including commercial applications. To alter this software and redistribute it freely,
if the origin of this software is not misrepresented.
*/
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("NEC V30MZ Emulator", "Section_legal_v30mz"); ?>
<blockquote>
<pre>
/* This NEC V30MZ emulator may be used for purposes both commercial and noncommercial if you give the author, Bryan McPhail,
   a small credit somewhere(such as in the documentation for an executable package).
*/
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("NEC V30MZ disassembler(modified BOCHS x86 disassembler)", "Section_legal_v30mzdis"); ?>
<blockquote>
<i>Caution:  Bochs' code is under the LGPL, but it is unclear if "or (at your option) any later version." applies to the x86 disassembler code.</i>
<pre>
This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2 of the License, or (at your option) any later version.
 
This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.
 
You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("Cygne", "Section_legal_cygne", "http://cygne.emuunlim.com/"); ?>
<p>
Cygne is distributed under the terms of the GNU GPL Version 2, 1991.<br>Copyright 2002 Dox, dox@space.pl.
</p>
<?php EndSection(); ?>

<?php BeginSection("FCE Ultra", "Section_legal_fceu"); ?>
<blockquote>
<pre>
/* FCE Ultra - NES/Famicom Emulator
 *
 *  Copyright (C) 1998 BERO
 *  Copyright (C) 2002 Xodnizel
 *  Copyright (C) 2003 CaH4e3
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("QuickLZ", "Section_legal_quicklz", "http://www.quicklz.com/"); ?>
<blockquote>
<pre>
// QuickLZ data compression library
// Copyright (C) 2006-2008 Lasse Mikkel Reinhold
// lar@quicklz.com
//
// QuickLZ can be used for free under the GPL-1 or GPL-2 license (where anything 
// released into public must be open source) or under a commercial license if such 
// has been acquired (see http://www.quicklz.com/order.html). The commercial license 
// does not cover derived or ported versions created by third parties under GPL.
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("Q-Subchannel CRC16 Code", "Section_legal_cdrdao", "http://cdrdao.sourceforge.net/"); ?>
<blockquote>
<pre>
/*  cdrdao - write audio CD-Rs in disc-at-once mode
 *
 *  Copyright (C) 1998  Andreas Mueller <mueller@daneb.ping.de>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */
</pre>
</blockquote>

<?php EndSection(); ?>

<?php BeginSection("SMS Plus", "Section_legal_sms_plus", "http://www.techno-junk.org/"); ?>
<blockquote>
<pre>
    Copyright (C) 1998-2004  Charles MacDonald

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("Genesis Plus", "Section_legal_genesis_plus", "http://www.techno-junk.org/"); ?>
<blockquote>
<pre>
/*
    Copyright (C) 1998, 1999, 2000, 2001, 2002, 2003  Charles Mac Donald

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("Genesis Plus GX", "Section_legal_genesis_plus_gx"); ?>
<blockquote>
<prE>
 *
 *  Copyright (C) 2007, 2008, 2009 EkeEke
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("EMU2413(used in SMS emulation)", "Section_legal_emu2413_sms"); ?>
<blockquote>
<pre>
  Copyright (C) Mitsutaka Okazaki 2004

  This software is provided 'as-is', without any express or implied warranty.
  In no event will the authors be held liable for any damages arising from
  the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not
     be misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("CD-ROM data correction code", "Section_legal_dvdisaster"); ?>
<blockquote>
<pre>
/*  dvdisaster: Additional error correction for optical media.
 *  Copyright (C) 2004-2007 Carsten Gnoerlich.
 *  Project home page: http://www.dvdisaster.com
 *  Email: carsten@dvdisaster.com  -or-  cgnoerlich@fsfe.org
 *
 *  The Reed-Solomon error correction draws a lot of inspiration - and even code -
 *  from Phil Karn's excellent Reed-Solomon library: http://www.ka9q.net/code/fec/
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA,
 *  or direct your browser at http://www.gnu.org.
 */
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("YM2612 Emulator", "Section_legal_ym2612"); ?>
<blockquote>
<pre>
/* Copyright (C) 2002 St�phane Dallongeville (gens AT consolemul.com) */
/* Copyright (C) 2004-2006 Shay Green. This module is free software; you
can redistribute it and/or modify it under the terms of the GNU Lesser
General Public License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version. This
module is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
details. You should have received a copy of the GNU Lesser General Public
License along with this module; if not, write to the Free Software Foundation,
Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA */
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("Sega Genesis SVP/SSP16 Emulator", "Section_legal_svp_ssp16"); ?>
<blockquote>
<pre>
/*
 * basic, incomplete SSP160x (SSP1601?) interpreter
 * with SVP memory controller emu
 *
 * Copyright (c) Gražvydas "notaz" Ignotas, 2008
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the organization nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("Speex Resampler", "Section_legal_speex", "http://speex.org/"); ?>
<blockquote>
<pre>
/* Copyright (C) 2007-2008 Jean-Marc Valin
   Copyright (C) 2008      Thorvald Natvig

   File: resample.c
   Arbitrary resampling code

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are
   met:

   1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

   3. The name of the author may not be used to endorse or promote products
   derived from this software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
   IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
   OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
   DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
   INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
   (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
   SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
   HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
   STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
   ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
   POSSIBILITY OF SUCH DAMAGE.
*/
</pre>
</blockquote>
 <?php EndSection(); ?>

<?php BeginSection("SABR v3.0 Shader", "Section_legal_sabr"); ?>
<blockquote>
<pre>
        SABR v3.0 Shader
        Joshua Street

        Portions of this algorithm were taken from Hyllian's 5xBR v3.7c
        shader.

        This program is free software; you can redistribute it and/or
        modify it under the terms of the GNU General Public License
        as published by the Free Software Foundation; either version 2
        of the License, or (at your option) any later version.

        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.

        You should have received a copy of the GNU General Public License
        along with this program; if not, write to the Free Software
        Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
</pre>
</blockquote>
<?php EndSection(); ?>

<?php BeginSection("ffmpeg cputest", "Section_legal_ffmpeg"); ?>
<blockquote>
<pre>
/*
 * CPU detection code, extracted from mmx.h
 * (c)1997-99 by H. Dietz and R. Fisher
 * Converted to C and improved by Fabrice Bellard.
 *
 * This file is part of FFmpeg.
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */
</pre>
</blockquote>
<?php EndSection(); ?>

<?php EndSection(); ?>

<?php EndPage(); ?>

