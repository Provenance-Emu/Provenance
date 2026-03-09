This is yet another SEGA 8 bit and 16 bit console emulator.

It can run games developed for most consumer hardware released
by SEGA, up to and including the 32X:
- **16 bit systems:** Mega Drive/Genesis, Sega/Mega CD, 32X, Pico
- **8 bit systems**: SG-1000, SC-3000, Master System/Mark III, Game Gear

PicoDrive was originally created with ARM-based handheld devices
in mind, but later received various cross-platform improvements
such as SH2 recompilers for MIPS (mips32r2), ARM64 (armv8), RISC-V (RV64IM)
and PowerPC (G4/2.03).

PicoDrive was the first software to properly emulate Virtua Racing and
its SVP chip.

At present, most development activity occurs in
[irixxxx's fork](https://github.com/irixxxx/picodrive);
[notaz's repo](https://github.com/notaz/picodrive) is updated less frequently.

### Using MSU, MD+/32X+, and Mode 1 on Sega/Mega CD

PicoDrive supports using CD audio enhanced cartridge games in all 3 formats.
To start an enhanced cartridge, load the .cue or .chd file. The cartridge
file should have the same base name and be placed in the same directory.
Further instructions can be found in `platform/base_readme.txt`.

### Sega Pico and Storyware Pages

PicoDrive can use Storyware pages and pad overlays in png format in the same
directory as the cartridge image. The selected page is displayed automatically
if the pen is used on the storyware or pad. Details about how to correctly name
the pages can be found in the *How to run Sega Pico games* section in
`platform/base_readme.txt`.

### Sega Pico and SC-3000 Keyboards

PicoDrive provides support for the Pico and SC-3000 keyboards. This can be
enabled in the `Controls` configuration menu. Once enabled, keyboard input may
be activated via the `Keyboard` emulator hotkey.

Both physical keyboard support and a virtual keyboard overlay are available.
Physical keyboards are assigned a default key mapping corresponding to an
American PC layout, but the mapping can be redefined in the `Controls`
configuration menu. Note that only 'unmodified' physical key presses (e.g.
`A`, `1` etc) can be mapped to emulated keyboard input; special characters
entered via modifier/meta keys (e.g. `Ctrl`, `Shift` etc) will not work.
Additional information may be found in `platform/base_readme.txt`.

### Sega SC-3000 Cassette Drive

In addition to keyboard support, PicoDrive emulates the SC-3000 cassette tape
drive which may be used in conjunction with BASIC cartridges. Tape emulation
includes an automatic start/stop feature, where the tape is only advanced when
it is accessed by the SC-3000; manual pausing of the tape is unnecessary for
multi-part loading or saving.

PicoDrive supports tape files in `WAV` and `bitstream` format.

### Gallery

Some images of demos and homebrew software:

| ![Titan Overdrive 2](https://github.com/irixxxx/picodrive/assets/31696370/02a4295b-ac9d-4114-bcd1-b5dd6e5930d0) | ![Raycast Demo](https://github.com/irixxxx/picodrive/assets/31696370/6e9c0bfe-49a9-45aa-bad7-544de065e388) | ![OpenLara](https://github.com/irixxxx/picodrive/assets/31696370/8a00002a-5c10-4d1d-a948-739bf978282a) |
| --- | --- | --- |
| [_MegaDrive: Titan Overdrive 2_](https://demozoo.org/productions/170767/) | [_MegaCD: RaycastDemo_](https://github.com/matteusbeus/RaycastDemo) | [_32X: OpenLara_](https://github.com/XProger/OpenLara/releases) |
|![Titan Overdrive 2](https://github.com/irixxxx/picodrive/assets/31696370/2e263e81-51c8-4daa-ab16-0b2cd5554f84)|![DMA David](https://github.com/irixxxx/picodrive/assets/31696370/fbbeac15-8665-4d3e-9729-d1f8c35e417a)|![Doom Resurrection](https://github.com/irixxxx/picodrive/assets/31696370/db7b7153-b917-4850-8442-a748c2fbb968)|
| [_MegaDrive: Titan Overdrive 2_](https://www.pouet.net/prod.php?which=69648) | [_MegaDrive: DMA David_](http://www.mode5.net/DMA_David.html) | [_32X: Doom Resurrection_](https://archive.org/details/doom-32x-all-versions) |

| ![Cheril Perils Classics](https://github.com/irixxxx/picodrive/assets/31696370/653914a4-9f90-45f8-bd91-56e784df7550) | ![Stygian Quest](https://github.com/irixxxx/picodrive/assets/31696370/8196801b-85c8-4d84-97e1-ae57ab3d577f) | ![Sword of Stone](https://github.com/irixxxx/picodrive/assets/31696370/3c4a8f40-dad6-4fa4-b188-46b428a4b8c6) |
| --- | --- | --- |
| [_SG-1000: Cheril Perils Classic_](https://www.smspower.org/Homebrew/CherilPerilsClassic-SG) | [_MasterSystem: Stygian Quest_](https://www.smspower.org/Homebrew/StygianQuest-SMS) | [_GameGear: The Sword of Stone_](https://www.smspower.org/Homebrew/SwordOfStone-GG) |
| ![Nyan Cat](https://github.com/irixxxx/picodrive/assets/31696370/6fe0d38b-549d-4faa-9351-b260a89dc745) | ![Anguna the Prison Dungeon](https://github.com/irixxxx/picodrive/assets/31696370/3264b962-7da2-4257-9ff7-1b509bd50cdf) | ![Turrican](https://github.com/irixxxx/picodrive/assets/31696370/c4eb2f2c-806e-4f4b-ac94-5c2cda82e962) |
| [_SG-1000: Nyan Cat_](https://www.smspower.org/Homebrew/NyanCat-SG) | [_MS: Anguna the Prison Dungeon_](https://www.smspower.org/Homebrew/AngunaThePrisonDungeon-SMS) | [_GameGear: Turrican_](https://www.smspower.org/Homebrew/GGTurrican-GG) |

### Compiling

For platforms where release builds are provided, the simplest method is to
use the release script `tools/release.sh`. See the script itself for details.
To create platform builds run the command:

```
tools/release.sh [version] [platforms...]
```

This will generate a file for each platform in the `release-[version]` directory.
A list of supported platforms can be found in the release script.

These commands should create an executable for a unixoid platform not included in the list:

```
configure --platform=generic
make
```

To compile PicoDrive as a libretro core, use this command:

```
make -f Makefile.libretro
```

### Helix MP3 decoder for ARM

For 32 bit ARM platforms, the optimized helix MP3 decoder can be used to play
MP3 audio files with CD games. Due to licensing issues, the helix source files
cannot be provided here; if you have obtained the sources legally, place them in
the `platform/common/helix` directory.

To compile the helix sources:

- Set the environment variable `CROSS_COMPILE` to your cross compiler prefix
(e.g. `arm-linux-gnueabi-`)
- Set the environment variable `LIBGCC` to your cross compiler's `libgcc.a`
(e.g. `/usr/lib/gcc-cross/arm-linux-gnueabi/4.7/libgcc.a`)
- Run the command:
```
make -C platform/common/helix CROSS_COMPILE=$CROSS_COMPILE LIBGCC=$LIBGCC
```
- Copy the resulting shared library named `${CROSS_COMPILE}helix_mp3.so` as
`libhelix.so` to the directory containing the PicoDrive binary on the target device.

In addition, helix support must be enabled in PicoDrive itself by compiling with:

```
make PLATFORM_MP3=1
```

This switch is enabled automatically for Gamepark Holdings devices (`gp2x`,
`caanoo` and `wiz`). Without installing `libhelix.so`, these devices will not play
MP3 audio.

### Installing

The release script produces packages or zip archives which have to be installed
manually on the target device. Usually this involves unpacking the archive or 
copying the package to a directory on either the internal device storage or an
SD card. Device-specific instructions can be found on the internet.


Send bug reports, fixes etc. to <derkub@gmail.com>
