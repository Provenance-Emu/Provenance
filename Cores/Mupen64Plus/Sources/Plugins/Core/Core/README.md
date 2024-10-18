# Mupen64Plus-Core README

[![TravisCI Build Status](https://travis-ci.org/mupen64plus/mupen64plus-core.svg?branch=master)](https://travis-ci.org/mupen64plus/mupen64plus-core) 
[![Coverity Scan Build Status](https://scan.coverity.com/projects/4381/badge.svg)](https://scan.coverity.com/projects/mupen64plus-core)
[![AppVeyor Build status](https://ci.appveyor.com/api/projects/status/a1ua5t87n2w8a7fc?svg=true)](https://ci.appveyor.com/project/Narann/mupen64plus-core)

More documentation can be found on the [Mupen64Plus website](https://mupen64plus.org/docs/)
and you can find a more complete README file on the [wiki](https://mupen64plus.org/wiki/index.php/README).

Mupen64Plus is based off of mupen64, originally created by Hacktarux. This
package contains only the Mupen64Plus core library.  For a fully functional
emulator, the user must also install graphics, sound, input, and RSP plugins,
as well as a user interface program (called a front-end).

### README Sections
  1. Requirements and Prerequisites
    - Binary
    - Source
  2. Building From Source
  3. Installation
    - Binary
    - Source
    - Custom Installation Path
  4. Key Commands In Emulator

## 1. Requirements and Pre-requisites

**Binary Package Requirements**

  - SDL 1.2 or 2.0
  - libpng
  - freetype 2
  - zlib 

**Source Build Requirements**

In addition to the binary libraries, the following packages are required if you
build Mupen64Plus from source:

  - GNU C and C++ compiler, libraries, and headers
  - GNU make
  - Nasm
  - Development packages for all the libraries above

## 2. Building From Source
If you downloaded the binary distribution of Mupen64Plus, skip to the
Installation process (Section 3). To build the source distribution, unzip and cd into the
projects/unix directory, then build using make:

```
 $ unzip mupen64plus-core-x-y-z-src.zip
 $ cd mupen64plus-core-x-y-z-src/projects/unix
 $ make all
```

Type `make` by itself to view all available build options:

```
 $ make
 Mupen64Plus makefile. 
   Targets:
     all           == Build Mupen64Plus and all plugins
     clean         == remove object files
     install       == Install Mupen64Plus and all plugins
     uninstall     == Uninstall Mupen64Plus and all plugins
   Options:
     BITS=32       == build 32-bit binaries on 64-bit machine
     LIRC=1        == enable LIRC support
     NO_ASM=1      == build without assembly (no dynamic recompiler or MMX/SSE code)
     USE_GLES=1    == build against GLESv2 instead of OpenGL
     VC=1          == build against Broadcom Videocore GLESv2
     NEON=1        == (ARM only) build for hard floating point environments
     VFP_HARD=1    == (ARM only) full hardware floating point ABI
     SHAREDIR=path == extra path to search for shared data files
     WARNFLAGS=flag == compiler warning levels (default: -Wall)
     OPTFLAGS=flag == compiler optimization (default: -O3)
     PIC=(1|0)     == Force enable/disable of position independent code
     OSD=(1|0)     == Enable/disable build of OpenGL On-screen display
     NEW_DYNAREC=1 == Replace dynamic recompiler with Ari64's experimental dynarec
     POSTFIX=name  == String added to the name of the the build (default: '')
   Install Options:
     PREFIX=path   == install/uninstall prefix (default: /usr/local/)
     SHAREDIR=path == path to install shared data (default: PREFIX/share/mupen64plus/)
     LIBDIR=path   == path to install plugin libs (default: PREFIX/lib)
     INCDIR=path   == path to install core header files (default: PREFIX/include/mupen64plus)
     DESTDIR=path  == path to prepend to all installation paths (only for packagers)
   Debugging Options:
     PROFILE=1     == build gprof instrumentation into binaries for profiling
     DEBUG=1       == add debugging symbols to binaries
     DEBUGGER=1    == build graphical debugger
     DBG_CORE=1    == print debugging info in r4300 core
     DBG_COUNT=1   == print R4300 instruction count totals (64-bit dynarec only)
     DBG_COMPARE=1 == enable core-synchronized r4300 debugging
     DBG_TIMING=1  == print timing data
     DBG_PROFILE=1 == dump profiling data for r4300 dynarec to data file
     V=1           == show verbose compiler output
```

## 3. Installation
**Binary Distribution**

To install the binary distribution of Mupen64Plus, su to root and run the
provided install.sh script:

```
 $ su
 # ./install.sh
 # exit
 $
```

The install script will copy the executable to __*/usr/local/bin*__ and a directory
called __*/usr/local/share/mupen64plus*__ will be created to hold plugins and other
files used by mupen64plus.

>NOTE:
By default, install.sh uses __*/usr/local*__ for the install prefix. Although
the user can specify an alternate prefix to install.sh at the commandline, the
mupen64plus binary was compiled to look for the install directory in __*/usr/local*__,
so specifying an alternate prefix to install.sh will cause problems (the
mupen64plus front-end application will not find the directory containing the
core library) unless the directory to which you install it is known by your
dynamic library loader (ie, included in __*/etc/ld.conf.so*__)
>
>If you want to use a prefix other than /usr/local, you may also download the
source code package and build with the PREFIX option (see below).

**Source Distribution**

After building mupen64plus and all plugins, su to root and type `make install`
to install Mupen64Plus. The install process will copy the executable to
__*$PREFIX/bin*__ and a directory called __*$PREFIX/share/mupen64plus*__ will be created
to hold plugins and other files used by mupen64plus. By default, PREFIX is set
to __*/usr/local*__. This can be changed by passing the PREFIX option to make. 
>NOTE:
You must pass the prefix, when building AND installing. For example, to install
mupen64plus to __*/usr*__, do this:
```
 $ make PREFIX=/usr all
 $ sudo make PREFIX=/usr install
 $
```

**Custom Installation Paths**

You may customize the instalation of Mupen64Plus by using the options for the install.sh script:

> Usage: `install.sh [PREFIX] [SHAREDIR] [BINDIR] [LIBDIR] [MANDIR]`
> 
>__PREFIX__ - installation directories prefix (default: __*/usr/local*__)
__SHAREDIR__ - path to Mupen64Plus shared data files (default: __*PREFIX/share/mupen64plus*__)
__BINDIR__ - path to Mupen64Plus binary program files (default: __*$PREFIX/bin*__)
__LIBDIR__ - path to Mupen64Plus plugin files (default: __*$SHAREDIR/plugins*__)
__MANDIR__ - path to manual files (default: __*$PREFIX/man/man1*__)

You must pass the same options to the uninstall.sh script when uninstalling in order to remove
all of the Mupen64Plus files.

You should install the Mupen64Plus plugins (libraries) in their own folder. If you install them
in a common directory such as __*/usr/lib*__ and then later uninstall them with
`sudo uninstall.sh LIBDIR=/usr/lib`, it will delete all system libraries.

If you install with SHAREDIR in a place other than __*/usr/local/share/mupen64plus*__ or
__*/usr/share/mupen64plus*__, and BINDIR is not the same as SHAREDIR, then users will have to run
Mupen64Plus with the `--installdir=` option, otherwise they will get an error. The mupen64plus
executable looks in up to 5 different directories in order to find the Shared Data Directory.
The order in which the directories are searched is:

- directory specified on command line with `--installdir`
- same directory as the mupen64plus binary
- __*/usr/local/share/mupen64plus*__
- __*/usr/share/mupen64plus*__
- current working directory

If you choose to install the plugins in a non-standard location (someplace other than
__*$SHAREDIR/plugins*__), then you must set the PluginDirectory parameter in the `mupen64plus.conf`
config file to the directory path in which the plugins have been installed.

## 4. Key Commands In Emulator
The keys or joystick/mouse inputs which will be mapped to the N64 controller
for playing the games are determined by the input plugin.  The emulator core
also supports several key commands during emulation, which may be configured by
editing the __*~/.config/mupen64plus/mupen64plus.cfg*__ file.  They are:
- **Escape (Esc)** Quit the emulator
- **0-9** Select virtual 'slot' for save/load state (F5 and F7) commands
- **F5** Save emulator state
- **F7** Load emulator state
- **F9** Reset emulator
- **F10** Slow down emulator by 5%
- **F11** Speed up emulator by 5%
- **F12** Take screenshot
- **Alt-Enter** Toggle between windowed and fullscreen (may not be supported by all video plugins)
- **p or P** Pause on/off
- **m or M** Mute/unmute sound
- **g or G** Press "Game Shark" button (only if cheats are enabled)
- **/ or ?** Single frame advance while paused
- **F** Fast Forward (playback at 250% normal speed while F key is pressed)
- **[** Decrease volume
- **]** Increase volume


