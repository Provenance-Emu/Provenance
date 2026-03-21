# Provenance StikDebug Scripts

These scripts extend [StikDebug](https://stikdebug.app) — a VPN-based iOS debugger — to enable Just-In-Time (JIT) compilation in Provenance.

## What is StikDebug?

StikDebug attaches a debugger to your sideloaded app over a VPN tunnel, granting the `get-task-allow` entitlement that iOS requires for JIT execution. It does not require a Mac, a jailbreak, or a developer certificate.

## Scripts

### `provenance.js` — iOS 26 W×X JIT helper

iOS 26 enforces **Write-XOR-Execute (W×X)** page protections via the Trusted Execution Monitor (TXM). Dynarec-based emulator cores (Mupen64Plus, Flycast) emit a `BRK #0x69` sentinel before each JIT write to signal that memory pages need dual-mapping:

- **RX mapping** — the address the CPU executes from (read+execute, no write)
- **RW alias** — a second mapping of the same physical pages the dynarec writes through

`provenance.js` intercepts `BRK #0x69`, asks TXM to authorise the region via `prepare_memory_region`, then creates the RW alias via `vm_remap`. This is identical to the pattern documented in the ManicEMU project.

**Required for:** Mupen64Plus dynarec, Flycast ARAM recompiler on iOS 26+.
**Not needed on:** iOS ≤ 25 (W×X not enforced), interpreter-only cores, or when using TrollStore / iOS 26 native JIT entitlement.

## Installation

1. Install [StikDebug](https://stikdebug.app) on your iOS device.
2. In StikDebug → **Scripts** → **Import**, select `provenance.js`.
3. Enable the script, then connect StikDebug to Provenance.
4. Launch Provenance and open a JIT-capable game (N64, Dreamcast).

## Supported Acquisition Methods

Provenance supports multiple JIT acquisition paths in priority order:

| Method | iOS Version | Requires |
|--------|-------------|----------|
| iOS 26 native JIT (`JITAuthorizer`) | 26+ | `com.apple.developer.kernel.allow-jit` entitlement |
| TrollStore | Any | TrollStore install |
| AltStore / SideStore (SideKit) | Any | AltStore or SideStore on same network |
| StikDebug | Any | StikDebug app |
| JITStreamer | Any | JITStreamer on Mac |
| Xcode debugger | Any | Xcode on Mac |

For most users without a Mac, **StikDebug** or **TrollStore** is the recommended path.

## See Also

- [Provenance Wiki — JIT Help](https://wiki.provenance-emu.com/jit-help)
- [StikDebug documentation](https://stikdebug.app/docs)
- Epic issue: [#2792 — JIT UX & Intelligent JIT Management](https://github.com/Provenance-Emu/Provenance/issues/2792)
