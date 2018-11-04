        _   _
       / \_/ \            ___  _      ____ 
       \     /___  ___   /   || | __ /    \ ____
        \   //   ||   \ /    || | \ \\  \_//    \
        /  //    ||   //  _  || |__\ \\  \    __/
        \_//  _  ||   \\_/ \_||______/ \  \\  \__
           \_/ \_||___/              \____/ \____\
     Yet Another Buggy And Uncomplete Saturn Emulator

        _________________________________________
        Copyright (c) 2002-2011 Yabause team


1) Compiling instructions...................................20
2) How to use Yabause.......................................68
3) Contact information.....................................217
4) Disclaimer..............................................233


1 Compiling instructions______________________________________

Yabause is written in C using the DirectX 8.0, OpenGL, GLUT, and
mini18n libraries, so you need a working C compiler(such as gcc) 
and these libraries, runtime and development packages:

  * You can find DirectX headers and libraries(for mingw) at
    http://alleg.sourceforge.net/wip.html as the file
    "dx80_mgw.zip". The actual runtime libraries(or
    headers/libraries for Visual C++) can be gotten from
    http://www.microsoft.com/DirectX

  * OpenGL should be included with your compiler, if it isn't,
    check on your compiler's website for links.

  * Check google for GLUT. I haven't been able to find a good
    source for it.

  * You can get mini18n from Yabause's sourceforge download page
    here: http://sourceforge.net/project/showfiles.php?group_id=89991&package_id=304859

Once these libraries installed, you should be ready to
install Yabause.

Compiling using mingw/cygwin__________________________________

All you have to do now is now is go into your mingw/cygwin
shell environment, go into the directory where you extracted
yabause, and type: "./configure". Once that's done(and there
was no errors), type: "make". It should now take some time to
compile so go grab yourself a sandwich or beer - whatever suits
your fancy and it should be done in a few minutes. Now all you
have to do is type "./src/yabause" in order to run it. 

Compiling using Visual C++____________________________________

Make sure you have the latest DirectX SDK and DDK installed. You
can get both of them from Microsoft's website.

Load up IDE that comes with Visual C++/Visual Studio, go into the
file menu, open an existing project. Go into the yabause's
src/windows directory and open yabause.sln. Now all you have
to do is build it like any other Visual C++ project.

You can compile for either x86 or x64(for those using Windows XP
x64 or Vista x64.


2 How to use Yabause__________________________________________

While not necessarily needed, it is recommended you get a Saturn
ROM BIOS image. Please don't ask us where to get one.

Execute "yabause". The program will open a settings window.

Basic Settings________________________________________________

The Disc Type setting allows you to choose whether you'd like to
use a real cdrom or a cdrom image of the game you're trying to
run.

The Cue/Iso File setting allows you to specify the location
of your Saturn game's cdrom image. 

The Drive Letter setting is for you to be able to choose which
cdrom drive you want yabause to use when trying to boot a game.

The SH2 Core setting is for you to be able to choose which SH2
Core to use. Unless you're a developer, chances are, you should
leave it as the default: "Fast Interpreter".

The Region setting allows you to choose which region of game
you'll be booting. In most cases, it's best to leave it as
"Auto-detect".

The Bios ROM File setting allows you to specify the location
of your Saturn ROM BIOS image. If you leave it blank, yabause
will try to emulate the bios instead. It's better to specify
a ROM BIOS image if you can since the emulated bios isn't
100% perfect and may not work with your games.

The Backup RAM File setting allows you to specify the location
of the Backup RAM file. This file allows yabause to store and
load save games.

The MPEG ROM File setting allows you to specify the location 
of a MPEG Card's ROM image. While not necessary, it does allow
you to test out the saturn's vcd capabilities.

The Cartridge Type setting allows you to choose which type of
external cartridge to emulate. Some carts also require you to
supply a rom filename, or a new filename for the emulator to
write to. You can enter that information in the field below it.

When you're done, just click on the "OK" button. If the bios
location was specified correctly, emulation should start and
you will see a brief animation of the saturn logo being formed. 

Special Note: Some settings require a restart of the program.

There's also settings specifically for video, sound, and input.

Video Settings________________________________________________

If you click on the "Video" tab another list of settings is
displayed. You can set the Video Core to either do hardware
rendering using OpenGL, software renderer(uses OpenGL the final
draw though), or disable drawing completely with the "None"
option. You can also "Enable Auto Frame-skipping" which basically
tries to skip rendering video frames if emulation is lagging in
an attempt to speed things up.

The Full Screen on startup setting allows you to set Yabause to
run using the full screen when started. You can also change what
resolution is used while in full screen.

The custom window size setting allows you to set the size of the
video display for yabause.

Sound Settings________________________________________________

If you click on the "Sound" tab another list of settings is
displayed. You can set the Sound Core to either do sound mixing
using DirectX Sound or disable sound completely with the "None"
option. You can also adjust the sound volume using the volume
slider underneath.

Input Settings________________________________________________

If you click on the "Input" tab another list of settings is
displayed. Here you can choose which peripheral(s) emulate. If
you press "Config" another window will pop up. Here can set which
device you'd like to use at the top of the window. Control
settings can be changed by clicking on the equivalent button, and
then when a new window pops up that says "waiting for input..."
press a key/button and that will set the new setting for that
control.

Log Settings__________________________________________________

If you've compiled your own copy of Yabause with the processor
define DEBUG, another tab will be available called "Log". This
allows you to control whether or not the program should be
logging emulation output using the "Enable Logging" setting. Log
Type tells the program whether it should write the output to a
file, or to a separate window so you can monitor the output while
you're running the program.

Here are the default key mappings(they may be subject to change):
Up arrow - Up
Left arrow - Left
Down arrow - Down
right arrow - Right
k - A button
l - B button
m - C button
u - X button
i - Y button
o - Z button
x - Left Trigger
z - Right Trigger
j - Start button
q - Quit program
F1 - Toggle FPS display
Alt-Enter - Toggle fullscreen/window mode
` - Enable Speed Throttle
1 - Toggle VDP2 NBG0 display
2 - Toggle VDP2 NBG1 display
3 - Toggle VDP2 NBG2 display
4 - Toggle VDP2 NBG3 display
5 - Toggle VDP2 RBG0 display
6 - Toggle VDP1 display
F2 - Load State from slot 1
F3 - Load State from slot 2
F4 - Load State from slot 3
F5 - Load State from slot 4
F6 - Load State from slot 5
F7 - Load State from slot 6
F8 - Load State from slot 7
F9 - Load State from slot 8
F10 - Load State from slot 9
Shift-F2 - Save State to slot 1
Shift-F3 - Save State to slot 2
Shift-F4 - Save State to slot 3
Shift-F5 - Save State to slot 4
Shift-F6 - Save State to slot 5
Shift-F7 - Save State to slot 6
Shift-F8 - Save State to slot 7
Shift-F9 - Save State to slot 8
Shift-F10 - Save State to slot 9

Command-line Options__________________________________________

You can also run the program using command-line options. To see a
full list, run "yabause --help" in the command prompt.


3 Contact information_________________________________________

General inquiries should go to:
E-mail:	guillaume@yabause.org
E-mail: cwx@cyberwarriorx.com

Windows Port-related inquiries should go to:
E-mail: cwx@cyberwarriorx.com

Web:    http://yabause.org

Please don't ask for roms, bios files or any other copyrighted
stuff. Please use the forum when you have any questions if
possible.


4 Disclaimer__________________________________________________

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License as 
published by the Free Software Foundation; either version 2 of 
the License, or (at your option) any later version.

This program is distributed in the hope that it will be
useful,but WITHOUT ANY WARRANTY; without even the implied
warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public
License along with this program; if not, write to the Free
Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
Boston, MA 02110-1301  USA

See the GNU General Public License details in COPYING.
