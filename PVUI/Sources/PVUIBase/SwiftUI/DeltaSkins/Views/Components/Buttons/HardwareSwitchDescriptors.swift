// Hardware switch model types and per-system switch data live in PVCoreBridge:
//   • HardwareSwitchPosition
//   • HardwareSwitchDescriptor
//   • HardwareSwitchProvider   (protocol)
//   • PV2600Button.hardwareSwitches
//   • PV7800Button.hardwareSwitches
//
// The entry point for the UI is SystemIdentifier.hardwareSwitches, which
// dynamically resolves switches from the system's button type — no hardcoded
// system-ID strings required.
@_exported import PVCoreBridge
