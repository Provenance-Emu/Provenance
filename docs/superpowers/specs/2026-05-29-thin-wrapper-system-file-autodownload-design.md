# Thin-Wrapper System-File Auto-Download — Design

**Date:** 2026-05-29
**Status:** Approved (design); URLs + zip utility confirmed — ready to implement
**Module:** `PVCoreBridgeRetro` (thin libretro wrapper)

## Purpose

Some thin-wrapper libretro cores need auxiliary "system" files that aren't the
game ROM and aren't shipped in the app bundle: PPSSPP wants its PSP assets
(fonts/`flash0`/`ppge_atlas`), EcWolf needs `ecwolf.pk3`, PrBoom needs
`prboom.wad`. When these are absent the core either warns ("system files are
missing, expect bugs") or misbehaves. This feature auto-downloads the missing
files from the libretro assets host on core launch, without blocking gameplay.

## Scope

- **In scope:** PPSSPP, EcWolf, PrBoom (thin wrapper). A small per-core manifest
  drives everything, so more cores can be added by appending entries.
- **Out of scope:** the thick wrapper (it already provisions its own assets);
  bundling files in the app; BIOS files that belong to the existing
  `BIOSPath`/CloudKit BIOS flow (real console BIOS, not core assets); a Settings
  UI for manual download (could be a later add).

## Approach (chosen: A — manifest + async provisioner + non-blocking launch hook)

Rejected alternatives: extending the thick wrapper's downloader (separate module,
couples the wrappers); bundling files in-app (inflates app size for files most
users fetch once).

## Components

### 1. `ThinSystemFileManifest`
New file under `PVCoreBridgeRetro/Sources/PVLibRetro/`. A pure declarative table:
core-id substring → list of `RequiredFile` entries. Each `RequiredFile`:

| field | meaning |
|---|---|
| `sentinelRelativePath` | path under the system dir whose existence means "already provisioned" (skip download) |
| `sourceURL` | absolute URL on the libretro assets host **(PENDING: exact URLs from user)** |
| `kind` | `.archive` (unzip into system dir) or `.file` (place verbatim at a destination path) |
| `destinationRelativePath` | for `.file`, where under the system dir it lands; for `.archive`, the dir to extract into |

Initial entries (paths to be confirmed by user before implementation):
- **PPSSPP** (`coreId contains "ppsspp"`): `PPSSPP.zip`, `.archive`, extract into system dir; sentinel ≈ `PPSSPP/flash0/font/…`.
- **EcWolf** (`"ecwolf"`): `ecwolf.pk3`, `.file`, sentinel = `ecwolf.pk3`.
- **PrBoom** (`"prboom"`): `prboom.wad`, `.file`, sentinel = `prboom.wad`.

### 2. `ThinSystemFileProvisioner`
An `actor` (or `@MainActor`-isolated class dispatching network work off-main).
API: `provision(coreId:systemDirectory:) async`. For each manifest entry whose
sentinel is absent:
1. `URLSession` download the `sourceURL` to a temp file.
2. If `.archive`, extract via the app's existing zip utility into a temp dir,
   then atomically move into the system dir; if `.file`, move into place at
   `destinationRelativePath`.
3. Post a progress/result notification (see UX).

Idempotent (sentinel check first), atomic (temp → move), and resilient
(per-entry failure is isolated and logged; never throws to the caller).

### 3. Launch hook
At thin-core launch, where `seedPSPFlash0Assets()` is invoked today
(`PVThinLibretroCore`), fire `Task.detached { await provisioner.provision(...) }`
**non-blocking** with the core's `coreId` and the resolved system directory
(= `GET_SYSTEM_DIRECTORY` = `BIOSPath`). Boot proceeds immediately.

## Data flow

```
core launch (PVThinLibretroCore)
  └─ seedPSPFlash0Assets()              (existing, bundle-derived)
  └─ Task.detached:
       provisioner.provision(coreId, systemDir)
         for entry in manifest[coreId] where sentinel missing:
           toast "Downloading <core> system files…"
           URLSession download → (unzip) → move into systemDir
           success: (files ready)   |   failure: warning toast, continue
```

## Error handling

- **Offline / download failure / bad archive:** log, post a warning toast
  ("Couldn't fetch <core> system files — some features may be missing"), leave
  any partial temp data unlinked, and let the core run. Retries next launch
  (sentinel still missing).
- **No manifest entry for the core:** no-op.
- **Already provisioned:** sentinel present → skip silently.

## UX

Reuse the app's existing toast mechanism (same surface as other in-game
notices). Start toast on first missing entry; success is silent; failure shows
the warning. No modal, no gameplay block.

## Platform

- iOS + tvOS. Files land in the system dir under `Documents` (persistent), so
  unlike the tvOS `Caches` concern that forces `seedPSPFlash0Assets` to re-seed,
  these survive. Standard `URLSession` internet download (not local-network), so
  no multicast/local-network entitlement implications.

## Testing

- **Unit (Tier 0–2 where possible):** manifest lookup by core id; sentinel
  presence logic; `.file` vs `.archive` destination resolution. Provisioner with
  a stubbed downloader (success, 404, offline, corrupt-archive) asserting:
  files placed, partial cleanup, idempotent skip, isolated per-entry failure.
- **Manual:** launch PPSSPP/EcWolf/PrBoom with system dir empty → toast →
  files appear → relaunch is silent; airplane-mode launch → warning toast, core
  still runs.

## Confirmed inputs (2026-05-29)

- **Host:** `https://buildbot.libretro.com/assets/system/<Name>.zip` (all are
  ZIP archives → `.archive` kind; names URL-encode spaces/parens). Full list the
  user provided (we ship a subset — only cores the thin wrapper actually serves):
  `PPSSPP.zip`, `ECWolf.zip`, `PrBoom.zip`, `blueMSX.zip`,
  `FinalBurn%20Neo%20%28hiscore%29.zip`, `MAME%202003-Plus.zip`, `MAME%202003.zip`,
  `XRick%20%28Rick%20Dangerous%29.zip`, `ScummVM.zip`,
  `NXEngine%20%28Cave%20Story%29.zip`, `LRPS2.zip`, `Dolphin.zip`,
  `DirkSimple.zip`, `Dinothawr.zip`. Initial manifest: PPSSPP, ECWolf, PrBoom.
- **Zip utility:** reuse `ArchiveManager` / `ArchiveExtractor`
  (`PVArchiving`, `extract(at:to:progress:)`). PVCoreBridgeRetro already depends
  on PVArchiving? — verify the package dep during implementation; add if missing.
- **Sentinel (revised):** rather than per-core internal file knowledge, write a
  per-core version stamp file (e.g. `<systemDir>/.pv_assets_<core>.stamp`) after
  a successful provision; presence of the stamp = "provisioned, skip." Matches
  the thick wrapper's asset-stamp pattern and works uniformly for any archive.

## Status note
The debugger-gated `fast_memory` fix (commit 78dca2f4b5) means PSP likely boots
+ runs WITHOUT these assets (they are fonts/UI, "preferred not required"). So
this auto-download is polish, not a boot fix — implement after the current
build's freeze/PSP/haptics results are validated, to avoid stacking untested
changes.
