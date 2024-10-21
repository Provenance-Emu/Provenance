           ___     _   _
          | _ \   | \_/ |
          |  _/   |  _  |
          | |     | | | |
          |_| OKE |_| |_| INI
          -------------------
             Version  0.60

  Homebrew-emulator for Pokémon-Mini!

  Latest version can be found in:
  http://pokemini.sourceforge.net/

  For hardware documentation, visit:
  http://wiki.sublab.net/index.php/Pokemon_Mini

> Keys & Information:

  To include real BIOS, place "bios.min" on the emulator's directory.
  When no "bios.min" is present, emulator will use Pokémon-Mini FreeBIOS.

  Pokémon-Mini     PC Keys
  ----------------------------
  D-PAD Left       Arrow Left
  D-PAD Right      Arrow Right
  D-PAD Up         Arrow Up
  D-PAD Down       Arrow Down
  Key A            Keyboard X
  Key B            Keyboard Z
  Key C            Keyboard S or C
  Power Button     Keyboard E
  Shock Detector   Keyboard A
  ----------------------------
  UI Menu          Keyboard Esc

  F9 will capture the screen and save as "snap_(sequence number).bmp"

  F10 can toggle between Fullscreen and Windowed.

  F11 will disable/enable speed throttle

  TAB can be hold to temporary disable speed throttle

> Supported multicarts:

  Type 0 - Disabled (Commercial, Prototype)
    Read only

  Type 1 - Normal 512KB Flash (AM29LV040B)
    Read, Erase, Write, Banking and Manufacturer ID

  Type 2 - Lupin's 512KB Flash (AM29LV040B)
    Read, Erase, Write, Banking and Manufacturer ID

> Command-Line:

  Usage:
  PokeMini [Options] rom.min

  Options:
  -freebios              Force FreeBIOS
  -bios otherbios.min    Load BIOS
  -noeeprom              Discard EEPROM data
  -eeprom pokemini.eep   Load/Save EEPROM file
  -eepromshare           Share EEPROM to all ROMs (default)
  -noeepromshare         Each ROM will use individual EEPROM
  -nostate               Discard State data (default)
  -state pokemini.sta    Load/Save state file
  -nortc                 No RTC
  -statertc              RTC time difference in savestates
  -hostrtc               RTC match the Host clock (def)
  -nosound               Disable sound
  -sound                 Same as -soundpiezo (def)
  -sounddirect           Use timer 3 directly for sound (default)
  -soundemulate          Use sound circuit emulation
  -sounddirectpwm        Same as direct, can play PWM samples
  -nopiezo               Disable piezo speaker filter
  -piezo                 Enable piezo speaker filter (def)
  -scanline              50% Scanline LCD filter
  -dotmatrix             LCD dot-matrix filter (def)
  -nofilter              No LCD filter
  -2shades               LCD Mode: No mixing
  -3shades               LCD Mode: Grey emulation
  -analog                LCD Mode: Pretend real LCD (default)
  -fullbattery           Emulate with a full battery (default)
  -lowbattery            Emulate with a weak battery
  -palette n             Select palette for colors (0 to 15)
  -rumblelvl 3           Rumble level (0 to 3)
  -nojoystick            Disable joystick (def)
  -joystick              Enable joystick
  -joyid 0               Set joystick ID
  -custom1light 0xFFFFFF Palette Custom 1 Light
  -custom1dark 0x000000  Palette Custom 1 Dark
  -custom2light 0xFFFFFF Palette Custom 2 Light
  -custom2dark 0x000000  Palette Custom 2 Dark
  -synccycles 8          Number of cycles per hardware sync.
  -multicart 0           Multicart type (0 to 2)
  -lcdcontrast 64        LCD contrast boost in percent
  -lcdbright 0           LCD brightness offset in percent

  Only on SDL platform:
  -dumpsound sound.wav   Dump sound into a WAV file
  -windowed              Display in window (default)
  -fullscreen            Display in fullscreen
  -zoom n                Zoom display: 1 to 4 (def 4)
  -bpp n                 Bits-Per-Pixel: 16 or 32 (def 16)

  Only on Debugger platform:
  -autorun 0             Autorun, 0=Off, 1=Full, 2=Dbg+Snd, 3=Dbg
  -windowed              Display in window (default)
  -fullscreen            Display in fullscreen
  -zoom n                Zoom display: 1 to 4 (def 4)
  -bpp n                 Bits-Per-Pixel: 16 or 32 (def 16)
  

> System requirements:

  No sound:
  Pentium III 733 Mhz or better recommended.

  With sound:
  Pentium IV 1.7 Ghz or better recommended.

  Note: Performance tests were based on 0.4.0 version

> History:

  -: 0.60 Changes :-
  Changed version format to only 2 fields to avoid confusion
  Fixed RTC month being reported wrong from host
  Adjusted graphics, now it display darker shades to match more closely the real system
  Added 2 new options: LCD contrast and LCD bright
  Changed the way analog LCD mode works, now it's less blurry and can do up to 5 shades without artifacts
  SDL port has been upgraded to SDL 2, this brings Haptic support and other improvements
  New Keyboard/Joystick option to allow checking inputs
  Applying joystick settings now can (re)enable the device
  Share EEPROM is now disabled by default
  Emulator can be compiled for 64-bit CPU without issues now
  Limited sync-cycles to 64 on 'accurancy' platforms
  Win32 Only:
    Corrected Direct3D issue in some GPUs
    Sound write position is now handled correctly
  NDS Only: Added 3-in-1 rumble support
  PSP Only:
    Analog stick now works
    Added FPS display under Platform... (default is off)
    Reached 100% emulation by skipping 1 frame, aparently hardware is limited to 60fps max
  Dreamcast Only:
    Improved sound latency (thanks BlueCrab).
    Added FPS display under Platform... (default is off)
  Debugger Only:
    Minor fixes
    Trace history is now 10000 instructions instead of 256
    Added copy & paste buttons to timing counters

  Older History can be found at:
  http://sourceforge.net/p/pokemini/wiki/History/

> License GPLv3 (emulator and tools):

PokeMini - Pokémon-Mini Emulator
Copyright (C) 2015  JustBurn

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

> Greetings & Links:

  Thank's to p0p, Dave|X, Onori
  goldmomo, asterick, DarkFader, Agilo
  MrBlinky, Wa, Lupin and everyone at
  #pmdev on IRC EFNET!
  Questions and Bugs reports are welcome!

  PokeMini webpage:
  https://sourceforge.net/projects/pokemini/

  Pokemon-Mini Hardware:
  http://wiki.sublab.net/index.php/Pokemon_Mini

  Pokémon-mini.net:
  http://www.pokemon-mini.net/

  MEGA - Museum of Electronic Games & Art:
  http://m-e-g-a.org/

  Minimon (other Pokemon-Mini emulator):
  http://www.sublab.net/projects/minimon/

  DarkFader Pokemon-Mini webpage:
  http://darkfader.net/pm/

  Agilo's Weblog:
  http://www.agilo.nl/
