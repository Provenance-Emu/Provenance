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

  Please read "readme.txt" for emulator information.

> Compiling PokeMini Source-Code:

  For big-endian platforms use _BIG_ENDIAN define

  Debugger
    GCC compiler, SDL libs and GTK+ libs are required
    Go to "platform/debug"
    Do "make clean" and "make", use "make win" on Windows OS

  SDL
    GCC compiler and SDL libs are required
    Go to "platform/pc"
    Do "make clean" and "make", use "make win" on Windows OS

  Win32
    Visual Studio 2005 or later is required
    DirectX SDK is required*
    Go to "platform/win32"
    Double click "PokeMini.sln"
    *Note: 
       June 2010 or later you will need to disable the DirectDraw driver,
       to disable define "NO_DIRECTDRAW" under "Preprocessor Definitions"

  NDS
    devkitPro is required
    Go to "platform/nds"
    Do "make clean" and "make"

  PSP
    devkitPro or PSP Toolchain are required
    Go to "platform/psp"
    Do "make clean" and "make"

  Dreamcast
    DevKitDC is required
    Go to "platform/dreamcast"
    Do "make clean" and "make"

  GameCube
    devkitPro is required
    This is an experimental platform and was never tested!
    Go to "platform/gamecube"
    Do "make clean" and "make"

  Wii
    devkitPro is required
    This is an experimental platform and was never tested!
    Go to "platform/wii"
    Do "make clean" and "make"

  GP2X Wiz (uWIZ lib)
    Toolchain for wiz is required
    libuwiz is required
    Go to "platform/uwiz"
    Modify OPENWIZ and HOST on "Makefile" to match your toolkit
    Do "make clean" and "make"

  GP2X Wiz (SDL lib)
    Toolchain for wiz is required
    Go to "platform/wizsdl"
    Modify OPENWIZ and HOST on "Makefile" to match your toolkit
    Do "make clean" and "make"

  Dingux
    Dingux toolkit is required
    Go to "platform/dingux"
    Modify DINGUX_TK and HOST on "Makefile" to match your toolkit
    Do "make clean" and "make"

> Compiling Tools Source-Code:

  BIN2C
    GCC compiler is required
    Go to "tools/bin2c"
    Do "make clean" and "make"

  PMAS (Assembler) - Maintained by DarkFader
    GCC compiler is required
    Download PMAS from http://sourceforge.net/projects/pmas/
    Deploy package into "tools/pmas" and go there
    Do "make clean" and "make"

  FreeBIOS
    PMAS and BIN2C are required
    Go to "freebios"
    Do "make clean" and "make"

  Color Mapper
    GCC compiler and GTK+ libs are required
    Go to "tools/color_mapper"
    Do "make clean" and "make", use "make win" on Windows OS
