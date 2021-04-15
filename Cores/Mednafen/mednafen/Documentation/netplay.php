<?php require("docgen.inc"); ?>

<?php BeginPage('', 'Netplay'); ?>

<?php BeginSection('Introduction', 'Section_intro'); ?>
 <p>
 Mednafen's netplay is standalone-server based, with multiple clients(players) connecting to the same server.  Save states are utilized upon connection, and whenever
 a player loads a save state on their end, so having decent bandwidth is critical, especially for newer systems with large save states like PS1 and Sega Saturn.
 Since nonvolatile memories(save RAM, floppy disks, etc.) are preserved in save states, you may want to backup any important save game files before netplaying
 with the corresponding game(s).  Using a different Mednafen installation, or Mednafen base directory, solely for netplay, is an option as well.  <font color="yellow">Be aware that the utilization of save states does bring about some potential <a href="mednafen.html#Section_security_savestates">security issues</a>.</font>
 </p>

 <p>
 Players with lower ping times to the server will have a latency/lag advantage.  To reduce latency, it's recommended to make the setting changes described <a href="mednafen.html#Section_minimize_video_lag">here</a>.  If emulating SNES
 games, try the alternate <a href="snes_faust.html">snes_faust</a> emulation module, with setting "<a href="snes_faust.html#snes_faust.spex">snes_faust.spex</a>" set to "1".
 </p>
<?php EndSection(); ?>


<?php BeginSection('Setting up the Server', 'Section_server_setup'); ?>
  <p>
  Download the latest "Mednafen-Server" <a href="https://mednafen.github.io/releases/#mednafen-server">release</a>.
  Untarballize it, and read the included "README" files for further instructions and caveats.
  </p>

<?php EndSection(); ?>

<?php BeginSection('Using Mednafen\'s netplay console', 'Section_using_console'); ?>
  <p>
  Pressing the 'T' key will bring up the network play console, or give it input focus if focus is lost.  From this console, 
  you may issue commands and chat.  Input focus to the console will be lost whenever the Enter/Return key is pressed.  The 'Escape' key(by default, shares assignment with the exit key) will exit the console entirely.
  Whenever text or important information is received, the console will appear, but without input focus.
  </p>
  <p>
  <table cellspacing="4" border="1">
  <tr><th colspan="2">Keys Relevant to the Text Box:</th></tr>
  <tr><th>Key:</th><th>Action:</th></tr>
  <tr><td>Up</td><td>Scroll up.</td></tr>
  <tr><td>Down</td><td>Scroll down.</td></tr>
  <tr><td>Page Up</td><td>Scroll up a page.</td></tr>
  <tr><td>Page Down</td><td>Scroll down a page.</td></tr>
  <tr><td nowrap>CTRL + Home</td><td>Scroll to the beginning.</td></tr>
  <tr><td nowrap>CTRL + End</td><td>Scroll to the end.</td></tr>
  </table>
  </p>
  <p>
  <table cellspacing=4" border="1">
  <tr><th colspan="2">Keys Relevant to the Prompt:</th></tr>
  <tr><th>Key:</th><th>Action:</th></tr>
  <tr><td>Left</td><td>Move cursor left.</td></tr>
  <tr><td>Right</td><td>Move cursor right.</td></tr>
  <tr><td nowrap>Home<td>Move cursor to the beginning.</td></tr>
  <tr><td nowrap>End<td>Move cursor to the end.</td></tr>
  <tr><td>Backspace</td><td>Remove character to the left of cursor position, and move cursor left.</td></tr>
  <tr><td nowrap>CTRL + Backspace</td><td>Remove all characters to the left of the cursor position, and move cursor to the beginning.</td></tr>
  <tr><td>Delete</td><td>Remove character at cursor position.</td></tr>
  <tr><td nowrap>CTRL + Delete</td><td>Remove characters at and after cursor position.</td></tr>
  <tr><td nowrap>CTRL + V <font size="-1"><i>(or)</i></font><br>SHIFT + Insert</td><td>Paste text from the clipboard.</td></tr>
  <tr><td>Enter</td><td>Process text entered into prompt.</td></tr>
  </table>
  </p>

  <table cellspacing="4" border="1">
   <tr><th>Command:</th><th>Description:</th><th>Relevant Settings:</th><th>Examples:</th></tr>
   <tr><td>/nick <i>nickname</i></td><td>Sets nickname.</td><td><a href="mednafen.html#netplay.nick">netplay.nick</a></td><td nowrap>/nick Deadly Pie<br />/nick 運命子猫</td></tr>
   <tr><td>/server <i>[hostname]</i> <i>[port]</i></td><td>Connects to specified netplay server.</td><td><a href="mednafen.html#netplay.host">netplay.host</a><br /><a href="mednafen.html#netplay.port">netplay.port</a></td><td nowrap>/server<br />/server netplay.fobby.net<br />/server helheim.net 4046<br />/server ::1</td></tr>
   <tr><td>/gamekey <i>[gamekey]</i></td><td>Sets(or clears) game key.</td><td><a href="mednafen.html#netplay.gamekey">netplay.gamekey</a></td><td>/gamekey pudding<br />/gamekey</td></tr>
   <tr><td>/ping</td><td>Pings the server.</td><td>-</td><td>/ping</td></tr>
   <tr><td>/swap <i>A</i> <i>B</i></td><td>Swap/Exchange all instances of controllers A and B(numbered from 1).</td><td>-</td><td>/swap 1 2</td></tr>
   <tr><td>/dupe <i>[A]</i> <i>[...]</i></td><td>Duplicate and take instances of specified controller(s)(numbered from 1).<p>Note: Multiple clients controlling the same controller currently does not work correctly with emulated analog-type gamepads, emulated mice, emulated lightguns, and any other emulated controller type that contains "analog" axis or button data.</p></td><td>-</td><td>/dupe 1</td></tr>
   <tr><td>/drop <i>[A]</i> <i>[...]</i></td><td>Drop all instances of specified controller(s).</td><td>-</td><td>/drop 1 2</td></tr>
   <tr><td>/take <i>[A]</i> <i>[...]</i></td><td>Take all instances of specified controller(s).</td><td>-</td><td>/take 1</td></tr>
   <tr><td>/list</td><td>List players in game.</td><td>-</td><td>/list</td></tr>
   <tr><td>/quit</td><td>Disconnects from the netplay server.</td><td>-</td><td>/quit</td></tr>
  </table>
  </p>

<?php EndSection(); ?>

<?php EndPage(); ?>
