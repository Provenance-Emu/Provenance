// Hardware switch model types and per-system switch data live in PVCoreBridge:
//   • HardwareSwitchPosition
//   • HardwareSwitchDescriptor
//   • HardwareMomentaryDescriptor
//   • HardwareSwitchProvider   (protocol — covers both toggle and momentary)
//
// Systems with hardware TOGGLE switch support:
//   Atari 2600  — Left Diff (A/B), Right Diff (A/B), TV Type (Color/BW)
//   Atari 7800  — Left Diff (A/B), Right Diff (A/B), TV Type (Color/BW)
//   Atari 5200  — TV Type (Color/BW)
//   Atari 8-bit — Option key, Select key
//   MSX / MSX2  — Left Diff, Right Diff
//   PC Engine / TurboGrafx-16 — Turbo I, Turbo II
//   PC Engine CD                — Turbo I, Turbo II
//   PC-FX / SuperGrafx          — Turbo I, Turbo II
//
// Systems with hardware MOMENTARY button support:
//   Sega Master System — PAUSE button (generates Z80 NMI, not a controller input)
//   MAME / FBNeo / CPS — SERVICE button (enters in-game test/dip-switch menu)
//     Note: Dip switches in arcade systems are game-specific; they live inside
//     the service menu and do not require system-level toggle descriptors.
//   NeoGeo / Geolith   — No hardware switches on AES consumer hardware;
//     MVS dip switches are game-specific and accessed via the service menu.
//
// The entry points for the UI are:
//   SystemIdentifier.hardwareSwitches        → toggle switch row
//   SystemIdentifier.hardwareMomentaryButtons → momentary button row
// Both resolve dynamically from the system's button type — no hardcoded system-ID
// strings required.
@_exported import PVCoreBridge
