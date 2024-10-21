           ___     _   _
          | _ \   | \_/ |
          |  _/   |  _  |
          | |     | | | |
          |_| OKE |_| |_| INI
          -------------------
             Version  0.60

  Homebrew-emulator for Pokémon-Mini!

  For hardware documentation, visit:
  http://wiki.sublab.net/index.php/Pokemon_Mini

  This information apply to handhelds or video game consoles.

> Keys & Information:

  ( NDS - Nintendo DS )

  Pokémon-Mini     NDS Keys
  ----------------------------
  D-PAD Left       D-PAD Left
  D-PAD Right      D-PAD Right
  D-PAD Up         D-PAD Up
  D-PAD Down       D-PAD Down
  Key A            Key A
  Key B            Key B
  Key C            Shoulder R
  Shock Detector   Shoulder L
  Power Button     Start
  ----------------------------
  UI Menu          Select

  ( PSP - PlayStation Portable )

  Pokémon-Mini     PSP Keys
  ----------------------------
  D-PAD Left       D-PAD Left
  D-PAD Right      D-PAD Right
  D-PAD Up         D-PAD Up
  D-PAD Down       D-PAD Down
  Key A            Circle
  Key B            Cross
  Key C            Shoulder R
  Shock Detector   Shoulder L
  Power Button     Start
  ----------------------------
  UI Menu          Select

  ( DC - Dreamcast )

  Pokémon-Mini     DC Keys
  ----------------------------
  D-PAD Left       D-PAD Left or Joystick
  D-PAD Right      D-PAD Right or Joystick
  D-PAD Up         D-PAD Up or Joystick
  D-PAD Down       D-PAD Down or Joystick
  Key A            Key B
  Key B            Key A
  Key C            Shoulder R
  Shock Detector   Shoulder L
  Power Button     Start
  ----------------------------
  UI Menu          Key X

  ( WIZ - GP2x Wiz )

  Pokémon-Mini     Wiz Keys
  ----------------------------
  D-PAD Left       D-PAD Left
  D-PAD Right      D-PAD Right
  D-PAD Up         D-PAD Up
  D-PAD Down       D-PAD Down
  Key A            Key B
  Key B            Key X
  Key C            Shoulder R
  Shock Detector   Shoulder L
  Power Button     Select
  ----------------------------
  UI Menu          Menu

  ( DINGUX - Dingoo in Linux )

  Pokémon-Mini     Dingoo Keys
  ----------------------------
  D-PAD Left       D-PAD Left
  D-PAD Right      D-PAD Right
  D-PAD Up         D-PAD Up
  D-PAD Down       D-PAD Down
  Key A            Key A
  Key B            Key B
  Key C            Shoulder R
  Shock Detector   Shoulder L
  Power Button     Start
  ----------------------------
  UI Menu          Select

  ( GAMECUBE - Nintendo GameCube )

  Pokémon-Mini     Wiz Keys
  ----------------------------
  D-PAD Left       D-PAD Left
  D-PAD Right      D-PAD Right
  D-PAD Up         D-PAD Up
  D-PAD Down       D-PAD Down
  Key A            Key A
  Key B            Key B
  Key C            Trigger R
  Shock Detector   Trigger L
  Power Button     Key Y
  ----------------------------
  UI Menu          Menu

  ( WII - Nintendo Wii )

  Pokémon-Mini     Wiz Keys
  ----------------------------
  D-PAD Left       Mote Left
  D-PAD Right      Mote Right
  D-PAD Up         Mote Up
  D-PAD Down       Mote Down
  Key A            Mote A
  Key B            Mote B
  Key C            Mote +
  Shock Detector   Mote -
  Power Button     Mote 2
  ----------------------------
  UI Menu          Mote 1

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
  PSP Only: Analog stick now works
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
