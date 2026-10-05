# Provenance Modifications to Mednafen

Mednafen upstream ships source tarballs only. Provenance builds it from
`Sources/mednafen/mednafen-src`, a git submodule of
[Provenance-Emu/mednafen-git](https://github.com/Provenance-Emu/mednafen-git), our fork
of `libretro-mirrors/mednafen-git`. The mirror has one commit per upstream release, with
the tarball contents at the repository root.

- `master` tracks the mirror and holds unmodified upstream releases. It is currently
  Mednafen 1.32.1, commit `f0ee9d5`.
- `Provenance-master` is `master` plus Provenance's patches, one commit each. The
  submodule pointer in this repo always names a `Provenance-master` commit.

The commits on `Provenance-master` are the source of truth for what Provenance
changes. `git log master..Provenance-master` inside the submodule lists them. The
table below summarises them.

| # | Patch | Files | Why | Origin |
|---|-------|-------|-----|--------|
| 1 | Disable `MDFN_HIDE` | `src/types.h` plus 34 declaration sites | `MDFN_HIDE` is hidden visibility. Provenance splits Mednafen into many SwiftPM targets, and the bridge needs to see `Emulated*` tables, `MDFNGameInfo`, `NVFS`, cheat tables and similar. The per-site `/*MDFN_HIDE*/` edits are no-ops once `types.h` defines it empty. | `82d5a6bfd8`, `d27bb892b9` |
| 2 | CHD disc images | new `src/cdrom/CDAccess_CHD.{cpp,h}`, `src/cdrom/CDAccess.cpp`, `src/mednafen.cpp` | Opens `.chd` through libchdr (`ThirdParty/libchdr`). | `0a839b60c9`, `5e9e80ed7f`, `2330b3e3a2`, `0c2f3ce8ab` |
| 3 | RetroAchievements RAM accessors | `src/{psx/psx,nes/nes,snes_faust/snes,pce/pce,pce_fast/pce,ss/ss}.cpp` | Adds `extern "C"` `mdfn_*_ptr()` / `mdfn_*_size()` functions, declared in `Sources/MednafenGameCoreC/include/MednafenGameCoreC/MednafenGameCoreC.h`. Saturn work RAM is `uint16` lane-swapped; the Swift bridge XORs offsets with 1 (`MednafenRcheevosByteSwapModeWord16`). | `ffbbe96e20` (#3510) |
| 4 | PSX teardown guards | `src/psx/psx.cpp` | Event updates skip a destroyed `CPU` or `CDC` (crash on close). | `54e6d9ba2b` |
| 5 | NES PPU surface guards | `src/nes/ppu/ppu.cpp` | Null surface checks and a clamped palette LUT index (close/rotation race). | `9451bc87cd` |
| 6 | Saturn SMPC default input | `src/ss/smpc.cpp` | `MiscInputPtr` never becomes null before the frontend sets port 12. | `b84e174086` |
| 7 | `MDFNI_LoadGame` rethrows | `src/mednafen.cpp` | Logs and rethrows instead of returning `NULL`, so the bridge can show the error. | `2330b3e3a2` |
| 8 | `MDFNI_Init` re-entry | `src/mednafen.cpp` | Drops the empty-system-list assert so Init can run again. | `c3cdcbc762` |
| 9 | Skip `TestSignedOverflow` | `src/tests.cpp` | That self test assumes `-fwrapv`. Upstream's configure passes it; `Package.swift` does not. | `c3cdcbc762` |
| 10 | More RetroAchievements RAM accessors | `src/{lynx/system,ngp/neopop,pcfx/pcfx,vb/vb,wswan/memory,gb/gb,gba/GBA,nes/fds,snes/interface}.cpp` | Same `extern "C"` pattern as #3 for Lynx, NGP, PC-FX, VB, WonderSwan, GB/GBC, GBA, FDS RAM and the bsnes SNES module. Plain bytes, no swap. Patch file: `mednafen-patches/0010-rcheevos-ram-accessors-more-systems.patch`. | not yet committed |
| 11 | NES PPU and cartridge RAM accessors | `src/nes/{cart,ppu/ppu}.cpp` | `extern "C"` `mdfn_nes_ppu_regs_*` (`PPU[4]`) and `mdfn_nes_cartram_*` (the RAM-backed pages mapped at $6000-$7FFF, read from `Page[]`/`PRGIsRAM[]`). Patch file: `mednafen-patches/0011-nes-ppu-cartram-accessors.patch`. | not yet committed |

None of the patches touch save-state code (`StateAction`, `SFORMAT`), so states are
compatible with stock Mednafen 1.32.1.

## Build glue that lives outside the submodule

Upstream's autotools build generates a few files. Provenance keeps its equivalents
under `Sources/mednafen/`, outside the fork:

- `config/config.h` is the configure output Mednafen reads through `HAVE_CONFIG_H`.
- `config/{trio,zstd,minilzo}/` hold the `AC_CONFIG_LINKS` header links, as symlinks
  into `mednafen-src`. They point at the internal copies.
- `glue/font-data-{12x13,18x18}.cpp` compile upstream's `src/video/font-data-*.c` as
  C++, because those files include the C++-only `<mednafen/types.h>`.
- `glue/wswan_main.cpp` compiles upstream's `src/wswan/main.cpp`. SwiftPM treats any
  target with a `main.*` source as an executable target.
- `include/module.modulemap` defines the `mednafen` Clang module that the bridge
  imports.

`Package.swift` lists every compiled source explicitly. Files it doesn't list are
ignored, so upstream code Provenance doesn't build (drivers, Win32, DOS, tests) stays
in the submodule untouched.

## mednafen-server (embedded netplay server)

`Sources/mednafen-server/` is a vendored copy of mednafen-server 0.5.2 (protocol 3,
matching the Mednafen 1.32.1 client). It is not a submodule; the changes are made in
place in `src/mednafen-server.cpp`, each one inside `#ifdef PROVENANCE_EMBEDDED_SERVER`
and marked "Provenance change". Without the define the file is upstream's program.

- `main()` becomes `mednafen_server_open()` (config, bind, listen; returns an error
  code) and `mednafen_server_run()` (the select loop on the caller's thread, until
  `mednafen_server_request_stop()`). The C API is `public/mednafen_server.h`.
- The config comes from a `MednafenServerConfig` struct instead of a config file.
- `exit()` becomes an error return. Shutdown closes the listen and client sockets and
  frees everything, so the server can start again in the same process.
- `printf`/`puts` go to a log callback (PVLogging, via the bridge) instead of stdout.
- No `mlockall()` and no process-wide `signal(SIGPIPE, SIG_IGN)`; accepted sockets get
  `SO_NOSIGPIPE` and `TCP_NODELAY` instead. Listen sockets get `SO_REUSEADDR`.
- IPv4 is required; a failed IPv6 listen socket is skipped.
- No stray global symbols: `ServerConfig` is `static`, the config-file `LoadConfig()` and
  `trim.inc` are compiled out, and `Package.swift` prefixes the helper files' functions
  (`md5_*`, `MBL_*`, `ErrnoHolder`) with `MednafenServer_` through `-D`, since they live
  in separate translation units and mednafen has its own md5 code.
- The loop publishes the player count of the biggest game (`mednafen_server_client_count()`).
- Host first: a remote (non-loopback) login is refused, with a server text the client
  shows, until a loopback client (the host's own) is in that game. Otherwise a joiner
  who resumed first would take controller 1 and have their state pushed onto the host.
  `mednafen_server_testing_treat_next_connection_as_remote()` lets tests simulate a
  remote player over loopback.

The bridge (`MednafenGameCoreBridge+Netplay.mm`) runs it on its own thread when the
player hosts, and implements the netplay driver callbacks `MDFND_NetplayText`,
`MDFND_NetplaySetHints` and `MDFND_CheckNeedExit`.
