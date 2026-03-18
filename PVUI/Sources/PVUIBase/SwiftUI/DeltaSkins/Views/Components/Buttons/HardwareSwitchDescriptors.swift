// Hardware switch model types and per-system switch data live in PVCoreBridge:
//   • HardwareSwitchPosition
//   • HardwareSwitchDescriptor
//   • HardwareSwitchProvider   (protocol)
//
// Systems with hardware switch support:
//   Atari 2600  — Left Diff (A/B), Right Diff (A/B), TV Type (Color/BW)
//   Atari 7800  — Left Diff (A/B), Right Diff (A/B), TV Type (Color/BW)
//   Atari 5200  — TV Type (Color/BW)
//   Atari 8-bit — Option key, Select key
//   MSX / MSX2  — Left Diff, Right Diff
//   PC Engine / TurboGrafx-16 — Turbo I, Turbo II
//   PC Engine CD                — Turbo I, Turbo II
//   PC-FX / SuperGrafx          — Turbo I, Turbo II
//
// The entry point for the UI is SystemIdentifier.hardwareSwitches, which
// dynamically resolves switches from the system's button type — no hardcoded
// system-ID strings required.
@_exported import PVCoreBridge
