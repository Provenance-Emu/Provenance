# Core Management Proposal

This document describes the new single-source-of-truth approach for managing libretro
buildbot cores in Provenance.

---

## Problem

Four URL list files were maintained manually in `CoresRetro/RetroArch/scripts/`:

| File | Description |
|------|-------------|
| `urls.txt` | iOS sideload build (~126 active cores) |
| `urls-appstore.txt` | iOS App Store build (subset, excludes dolphin + mcsoftserve) |
| `urls-tv.txt` | tvOS sideload build (~133 active cores) |
| `urls-appstore-tv.txt` | tvOS App Store build (subset) |

Plus their corresponding `.xcfilelist` files that mirror these lists. Any change to
a core — adding, removing, enabling, or toggling appstore status — required editing
multiple files by hand, making it easy to introduce inconsistencies.

---

## Solution: Option A — YAML Manifest + Python Generator (Chosen)

A single `CoresRetro/RetroArch/scripts/cores.yml` file is the new source of truth.
It contains one entry per core with all relevant metadata. A Python 3 script
(`Scripts/generate_core_lists.py`) reads this YAML and regenerates all 8 output files.

### cores.yml structure

```yaml
buildbot:
  base_url: "https://buildbot.libretro.com/nightly/apple"
  ios_path: "ios-arm64/latest"
  tvos_path: "tvos-arm64/latest"

cores:
  - name: fceumm
    ios: true
    tvos: true
    appstore: true
    enabled: true

  - name: dolphin
    ios: true
    tvos: true
    appstore: false
    enabled: true
    filename: "dolphin_libretro.dylib"
    appstore_excluded_reason: "Contains JIT/dynamic recompilation not permitted in App Store"

  - name: snes9x
    ios: true
    tvos: true
    appstore: true
    enabled: false   # globally disabled — commented out in all generated files

  - name: flycast
    ios: true
    tvos: true
    appstore: true
    enabled: true
    filename: "flycast_libretro.dylib"   # platform-neutral filename (no _ios/_tvos suffix)
```

### Core fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Core name (used to derive download filenames) |
| `ios` | bool | Included in iOS builds |
| `tvos` | bool | Included in tvOS builds |
| `appstore` | bool | Allowed in App Store builds (false = commented out in appstore files) |
| `enabled` | bool | If false, commented out in ALL generated files and omitted from xcfilelists |
| `filename` | string? | Custom filename for platform-neutral builds (no `_ios`/`_tvos` suffix) |
| `appstore_excluded_reason` | string? | Human-readable reason for App Store exclusion |

### URL derivation rules

For a core named `fceumm` on iOS:
- Standard filename: `fceumm_libretro_ios.dylib`
- Download URL: `{base_url}/{ios_path}/fceumm_libretro_ios.dylib.zip`

For a core with a custom `filename: "flycast_libretro.dylib"`:
- Same filename used for both iOS and tvOS
- iOS URL: `{base_url}/{ios_path}/flycast_libretro.dylib.zip`
- tvOS URL: `{base_url}/{tvos_path}/flycast_libretro.dylib.zip`

### Python generator usage

```bash
# Generate all output files (default command)
python3 Scripts/generate_core_lists.py generate

# Dry-run: show what would be written
python3 Scripts/generate_core_lists.py generate --dry-run

# Check which URLs are reachable on the buildbot
python3 Scripts/generate_core_lists.py validate

# Show diff between current files and what would be generated
python3 Scripts/generate_core_lists.py diff

# Import existing txt files into YAML format (for debugging/migration)
python3 Scripts/generate_core_lists.py bootstrap
```

The script requires only Python 3.8+ with no external dependencies (stdlib only).

### Generated output files

The generator produces these 8 files:

| File | Contents |
|------|----------|
| `urls.txt` | iOS sideload — all iOS cores, disabled ones commented |
| `urls-appstore.txt` | iOS App Store — appstore-excluded cores also commented |
| `urls-tv.txt` | tvOS sideload — all tvOS cores, disabled ones commented |
| `urls-appstore-tv.txt` | tvOS App Store — appstore-excluded cores also commented |
| `output_modules.xcfilelist` | iOS sideload xcfilelist (enabled only) |
| `output_modules_appstore_ios.xcfilelist` | iOS App Store xcfilelist |
| `output_modules_tv.xcfilelist` | tvOS sideload xcfilelist |
| `output_modules_appstore_tv.xcfilelist` | tvOS App Store xcfilelist |

### Adding a new core

1. Open `CoresRetro/RetroArch/scripts/cores.yml`
2. Add an entry under `cores:`:
   ```yaml
   - name: newcore
     ios: true
     tvos: true
     appstore: true
     enabled: true
   ```
3. Run the generator: `python3 Scripts/generate_core_lists.py generate`
4. Commit `cores.yml` and the regenerated files together.

---

## Option B — CoreManager Swift CLI (Advanced Tooling)

`Scripts/CoreManager/` is a Swift Package Manager executable that provides the same
functionality as the Python script, using Swift's type system and ArgumentParser.

### Building

```bash
cd Scripts/CoreManager
swift build -c release
.build/release/CoreManager --help
```

### Running subcommands

```bash
swift run CoreManager generate
swift run CoreManager validate
swift run CoreManager diff
swift run CoreManager bootstrap
```

### Package structure

```
Scripts/CoreManager/
  Package.swift
  Sources/CoreManager/
    main.swift           — ArgumentParser root command + subcommands
    CoreManifest.swift   — Data models (BuildbotConfig, CoreEntry, CoreManifest)
  Tests/CoreManagerTests/
    CoreManifestTests.swift  — XCTest coverage for model types
```

The Swift tool is an optional advanced option for developers who prefer it over
the Python script. Both tools read the same `cores.yml` and produce identical output.

---

## Migration Path

1. **Already done** — `cores.yml` is created from the existing 4 txt files.
2. **Run generator** — `python3 Scripts/generate_core_lists.py diff` should show no differences.
3. **CI integration** (optional future step) — Add a CI check that runs `diff` and fails
   if `cores.yml` and the generated files are out of sync.
4. **Deprecate manual editing** — All core changes go through `cores.yml` only.

---

## Known Platform Differences

| Core | iOS | tvOS | Notes |
|------|-----|------|-------|
| vitaquake2 | No | Yes | tvOS-only (disabled by default) |
| vitaquake2-rogue | No | Yes | tvOS-only (disabled by default) |
| vitaquake2-xatrix | No | Yes | tvOS-only (disabled by default) |
| vitaquake2-zaero | No | Yes | tvOS-only (disabled by default) |
| puau | No | Yes | tvOS-only |
| puau2021 | No | Yes | tvOS-only |
| dolphin | Both | Both | Excluded from App Store builds |
| mcsoftserve | Both | Both | Excluded from App Store builds |

## Platform-Neutral Filenames

These cores use a single filename without `_ios`/`_tvos` suffix, shared between platforms:

| Core | Filename |
|------|----------|
| dolphin | `dolphin_libretro.dylib` |
| flycast | `flycast_libretro.dylib` |
| fmsx | `fmsx_libretro.dylib` |
| melondsds | `melondsds_libretro.dylib` |
| ppsspp | `ppsspp_libretro.dylib` |
| vice_xscpu64 | `vice_xscpu64_ibretro.dylib` *(note: typo in upstream filename preserved)* |
