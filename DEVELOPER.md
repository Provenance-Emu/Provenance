# DEVELOPER.md

__Developers should start here first for breif instructions for building and working with the source code__

## Documentation

## JIT Capability Matrix

Provenance uses **two complementary JIT classification types**:

| Type | Module | Purpose |
|------|--------|---------|
| `PVPrimitives.PVJITRequirement` | `PVPrimitives` | Rich 4-case Swift enum; override in each `PVEmulatorCore` subclass |
| `PVCoreBridge.PVJITPlistRequirement` | `PVCoreBridge` | Simple 3-case plist-parsed type; populated at runtime by `CoreLoader` |

> **Note:** The two types have different names on purpose — both `PVEmulatorCore` and
> `PVCoreBridge` are `@_exported import`-ed by downstream modules, so using the same
> name in both would cause ambiguous-type compiler errors.

### `PVPrimitives.PVJITRequirement` — per-core Swift property

| Case | Meaning | Safe without JIT? |
|------|---------|-------------------|
| `.notSupported` | Core has no JIT code path | ✅ Yes |
| `.optional(fallback:)` | JIT improves perf/accuracy; interpreter fallback available | ✅ Yes |
| `.automaticWithFallback` | Core self-detects JIT and selects execution path automatically | ✅ Yes |
| `.requiredOrCrash` | Core crashes or produces garbage without JIT | ❌ No |

### Known JIT-Capable Cores

| Core | `PVJITRequirement` (Swift) | Notes |
|------|---------------------------|-------|
| Dolphin (Wii/GC) | `.automaticWithFallback` | Selects JIT or Cached Interpreter at startup; never crashes without JIT |
| melonDS (DS) | `.optional(fallback: "Interpreter")` | JIT recompiler boosts DS performance |
| DeSmuME 2015 (DS) | `.optional(fallback: "Interpreter")` | Older DS core, optional JIT |
| PCSX Rearmed (PSX) | `.optional(fallback: "Interpreter")` | ARM dynarec; interpreter always available |
| Mupen64Plus (N64) | `.optional(fallback: "Interpreter")` | JIT recompiler; interpreter fallback |
| PPSSPP (PSP) | `.optional(fallback: "Interpreter")` | JIT for full-speed PSP; interpreter available |
| Flycast (Dreamcast) | `.optional(fallback: "Interpreter")` | JIT recompiler available; interpreter fallback |
| Play! (PS2) | `.requiredOrCrash` | Crashes or produces garbage output without JIT |
| Azahar / Citra (3DS) | `.automaticWithFallback` | Auto-detects JIT; falls back to interpreter. `enableJIT` defaults to `true` for best performance. |
| emuThree (3DS) | `.automaticWithFallback` | Same Citra codebase; same automatic fallback behaviour. |

### Usage

Query a core's JIT requirement before launching a game:

```swift
let core: PVEmulatorCore = ...

switch core.jitRequirement {
case .notSupported:
    break  // no JIT needed — launch immediately
case .optional(let fallback):
    // Try to acquire JIT; warn user if unavailable (will run via fallback)
    acquireJITIfAvailable()
case .automaticWithFallback:
    // Attempt JIT acquisition, but launch regardless of outcome
    acquireJITIfAvailable()
case .requiredOrCrash:
    // Must acquire JIT or refuse to launch
    guard acquireJIT() else {
        showJITRequiredError()
        return
    }
}
```

### Adding a New Core

Override `jitRequirement` in the core's `PVEmulatorCore` subclass:

```swift
open override var jitRequirement: PVPrimitives.PVJITRequirement {
    .optional(fallback: "Interpreter")
}
```

The default implementation returns `.notSupported`, so only JIT-capable cores need to override.

Also add a `PVJITRequirement` key to the core's `Core.plist`:

```xml
<key>PVJITRequirement</key>
<string>optional</string>  <!-- "required" | "optional" | "notRequired" -->
```

### Auto-Enabling JIT-Disabled Cores

Some cores are shipped with `PVDisabled = true` because they require JIT to run at all
(e.g., Azahar/3DS). Mark them with `PVJITDisabledWithoutJIT = true` so the runtime can
auto-enable them once JIT is successfully acquired:

```xml
<key>PVDisabled</key>
<true/>
<key>PVJITDisabledWithoutJIT</key>
<true/>
<key>PVJITRequirement</key>
<string>required</string>
```

The app layer (#2794) will query `EmulatorCoreInfoPlist.jitDisabledWithoutJIT` to find
these cores and toggle them on when a JIT entitlement is obtained.

## Submodule Management

Provenance uses git submodules for emulator cores. Each core submodule is pinned to a specific commit (the gitlink in the tree). Some submodules also specify a `branch` in `.gitmodules`; this affects `git submodule update --remote` but **not** normal checkouts, which always use the pinned commit.

### Updating a Core Submodule to Fork HEAD

When a Provenance-Emu fork submodule has a `branch = <branch-name>` entry and you want to advance it:

```bash
# If this is a first-time checkout, ensure the submodule is initialized:
git submodule update --init Cores/<CoreName>/<submodule-dir>

# If you changed the submodule's URL or branch in .gitmodules, sync the local config:
git submodule sync -- Cores/<CoreName>/<submodule-dir>

# Sync just that submodule to the remote branch HEAD.
# Do NOT use --merge here: submodules are usually in detached-HEAD state after
# a normal checkout and --merge will fail or produce unexpected results.
git submodule update --remote Cores/<CoreName>/<submodule-dir>

# Review the new commit, then stage and commit
git add Cores/<CoreName>/<submodule-dir>
git commit -m "chore(<CoreName>): update submodule to <short-sha>"
```

Record the resulting commit hash in the changelog entry for traceability.

> **Note:** `git submodule update` (without `--remote`) always checks out the pinned gitlink commit, ignoring `branch`. Only `--remote` advances to the branch tip. Submodules are in a detached-HEAD state after a normal checkout; avoid `--merge`/`--rebase` unless you have already checked out a local branch inside the submodule.

## Building

### Setup Code Signing

- Copy `CodeSigning.xcconfig.sample` to `CodeSigning.xcconfig` and edit your relevent developer account details
- Accept any XCode / Swift Packagage Manager plugins (this will be presented to you by XCode at first build)
- Select scheme to build
    - I suggest building `Lite` first and working your way up to `XL` as you resolve any issues you may encouter in less time with the `Lite` app target.
    - Most users will want wither `Provenance-Release` or `Provenacne-XL (Release)`. The XL build includes more `RetroArch` and native local cores. See the build target and `./CoresRetro/RetroArch/Scripts/` build file lists for the most accurate list of cores for each target.
- If initial build fails, try again, as some source code files are generated lazily at compile time and sometimes XCode doesn't get the build order corrct 

### Realm Threading

When working with Realm and Swift Concurrency, it's important to remember that Realm objects are thread-confined, meaning they can only be accessed on the thread where they were created. Here's the recommended approach:

1. Use Object IDs or Primary Keys:
   Instead of passing the managed object directly, pass the object's ID or primary key to the other thread. This is safe because IDs and primary keys are simple value types.

   ```swift
   let objectId = managedObject.id // Assuming your object has an id property
   Task {
       await someAsyncFunction(objectId)
   }
   ```

2. Fetch the Object on the New Thread:
   In the async function, use the ID to fetch a new instance of the object from the Realm on that thread.

   ```swift
   func someAsyncFunction(_ objectId: ObjectId) async {
       let realm = try! await Realm()
       if let object = realm.object(ofType: YourObject.self, forPrimaryKey: objectId) {
           // Use the object here
       }
   }
   ```

3. Use Unmanaged Objects:
   If you need to pass actual data between threads, you can create an unmanaged copy of the object. This is useful when you don't need to update the object in the database.

   ```swift
   let unmanagedCopy = YourObject(value: managedObject)
   Task {
       await someAsyncFunction(unmanagedCopy)
   }
   ```

4. Use Realm's Built-in Threading Support:
   Realm provides some built-in support for working across threads. You can use `Realm.asyncOpen()` to open a Realm asynchronously:

   ```swift
   Task {
       do {
           let realm = try await Realm.asyncOpen()
           // Use realm here
       } catch {
           print("Failed to open realm: \(error.localizedDescription)")
       }
   }
   ```

5. Freeze Objects:
   Realm allows you to create a frozen copy of an object, which can be safely passed between threads:

   ```swift
   let frozenObject = managedObject.freeze()
   Task {
       await someAsyncFunction(frozenObject)
   }

   func someAsyncFunction(_ frozenObject: YourObject) async {
       // Use frozenObject here. It's immutable but can be safely accessed across threads.
   }
   ```

6. Use ThreadSafeReference:
   For more complex scenarios, you can use `ThreadSafeReference`:

   ```swift
   let reference = ThreadSafeReference(to: managedObject)
   Task {
       let realm = try! await Realm()
       guard let resolvedObject = realm.resolve(reference) else {
           return // The object has been deleted
       }
       // Use resolvedObject here
   }
   ```

Remember, when using Swift Concurrency with Realm:
- Always access Realm and its objects on the same thread they were created on.
- Use `@MainActor` for UI updates involving Realm objects.
- Be cautious with long-running transactions in async contexts to avoid blocking the thread.

By following these guidelines, you can safely work with Realm objects across different threads when using Swift Concurrency.

### Test ROMs

- https://provenance-emu.com/test_roms/240pee.nes
- https://provenance-emu.com/test_roms/240pee_mb.gba
- https://provenance-emu.com/test_roms/gb240p.gb

### Supported systems as of 2024.10.31

- Apple
  - Apple II
  - Macintosh

- Atari
  - Atari 2600
  - Atari 5200
  - Atari 7800
  - Atari 8bit Computer
  - Atari Jaguar
  - Atari Jaguar CD
  - Atari Lynx
  - Atari ST

- Bandai
  - WonderSwan

- CBS
  - CBS ColecoVision

- Enterprise
  - Enterprise 128

- IBM
  - IBM PC DOS

- Libretro
  - RetroArch

- Magnavox
  - Magnavox Odyssey2

- MAME
  - MAME

- Mattel
  - Mattel Intellivision

- NEC
  - PC98
  - PCFX
  - SuperGrafx
  - TurboGrafx-16
  - TurboGrafx-CD

- Nintendo
  - DS
  - Famicom Disk System
  - Game Boy
  - Game Boy Advance
  - Game Boy Color
  - Nintendo
  - Nintendo 64
  - Nintendo GameCube
  - Nintendo Wii
  - Pokémon mini
  - Super Nintendo
  - Virtual Boy

- Panasonic
  - 3DO

- Sega
  - 32X
  - Dreamcast
  - Game Gear
  - Genesis
  - Master System
  - Saturn
  - Sega CD
  - SG-1000

- Smith Engineering
  - Smith Engineering Vectrex

- SNK
  - Neo Geo
  - Neo Geo Pocket
  - Neo Geo Pocket Color

- Sony
  - PlayStation
  - PlayStation 2
  - PlayStation Portable

- Various
  - Game Music

- Watara
  - Supervision

- ZX
  - ZX Spectrum

## Audio Debugging notes

### GameBoy Advanced: 

Notes: Crackles sometimes, sounds slowed down

Logs:
🔍 GameAudioEngine2.swift:175 - streamDescription: Creating stream description - Rate: 44100.0, Channels: 2, Bits: 16
ℹ️ PVMetalViewController.swift:268 - updatePreferredFPS(): updatePreferredFPS (59)
🔍 GameAudioEngine2.swift:203 - updateSourceNode(): Entering updateSourceNode
🔍 GameAudioEngine2.swift:207 - updateSourceNode(): Detached existing source node
🔍 GameAudioEngine2.swift:175 - streamDescription: Creating stream description - Rate: 44100.0, Channels: 2, Bits: 16
🔍 GameAudioEngine2.swift:219 - updateSourceNode(): Using format: <AVAudioFormat 0x301b47840:  2 ch,  44100 Hz, Int16, interleaved>
🔍 GameAudioEngine2.swift:238 - updateSourceNode(): Attached new source node
🔍 GameAudioEngine2.swift:240 - updateSourceNode(): Exiting updateSourceNode
🔍 GameAudioEngine2.swift:266 - connectNodes(): Entering connectNodes
🔍 GameAudioEngine2.swift:273 - connectNodes(): Output format: <AVAudioFormat 0x30185d590:  2 ch,  48000 Hz, Float32, deinterleaved>

### Sega Genesis

Notes: Sounds slowed down, drunk. Sometimes pops / cracks

Logs:
🔍 GameAudioEngine2.swift:175 - streamDescription: Creating stream description - Rate: 44100.0, Channels: 1, Bits: 16
🔍 GameAudioEngine2.swift:219 - updateSourceNode(): Using format: <AVAudioFormat 0x301dcfa20:  1 ch,  44100 Hz, Int16>
🔍 GameAudioEngine2.swift:238 - updateSourceNode(): Attached new source node
🔍 GameAudioEngine2.swift:240 - updateSourceNode(): Exiting updateSourceNode
🔍 GameAudioEngine2.swift:266 - connectNodes(): Entering connectNodes
🔍 GameAudioEngine2.swift:273 - connectNodes(): Output format: <AVAudioFormat 0x301dced50:  2 ch,  48000 Hz, Float32, deinterleaved>
🔍 GameAudioEngine2.swift:297 - connectNodes(): Connected with format conversion: <AVAudioFormat 0x301dcfa20:  1 ch,  44100 Hz, Int16> -> <AVAudioFormat 0x301dcee90:  1 ch,  44100 Hz, Float32>
🔍 GameAudioEngine2.swift:304 - connectNodes(): Set main mixer node output volume to 1.0
🔍 GameAudioEngine2.swift:305 - connectNodes(): Exiting connectNodes

### NES via FCEUX

I think it sounds fine

Logs:
🔍 GameAudioEngine2.swift:175 - streamDescription: Creating stream description - Rate: 44100.0, Channels: 2, Bits: 16
🔍 GameAudioEngine2.swift:219 - updateSourceNode(): Using format: <AVAudioFormat 0x301afb4d0:  2 ch,  44100 Hz, Int16, interleaved>
🔍 GameAudioEngine2.swift:238 - updateSourceNode(): Attached new source node
🔍 GameAudioEngine2.swift:240 - updateSourceNode(): Exiting updateSourceNode
🔍 GameAudioEngine2.swift:175 - streamDescription: Creating stream description - Rate: 44100.0, Channels: 2, Bits: 16
🔍 GameAudioEngine2.swift:313 - updateSampleRateConversion(): Source rate: 44100.0, Target rate: 48000.0
🔍 GameAudioEngine2.swift:175 - streamDescription: Creating stream description - Rate: 44100.0, Channels: 2, Bits: 16
🔍 GameAudioEngine2.swift:314 - updateSampleRateConversion(): Source format: <AVAudioFormat 0x301b60320:  2 ch,  44100 Hz, Int16, interleaved>, Output format: <AVAudioFormat 0x301af9680:  2 ch,  48000 Hz, Float32, deinterleaved>
🔍 GameAudioEngine2.swift:324 - updateSampleRateConversion(): Setting sample rate conversion ratio: 1.0884354
🔍 GameAudioEngine2.swift:342 - updateSampleRateConversion(): Connecting with converter format: <AVAudioFormat 0x301b60370:  2 ch,  44100 Hz, Float32, deinterleaved>
🔍 GameAudioEngine2.swift:175 - streamDescription: Creating stream description - Rate: 44100.0, Channels: 2, Bits: 16
🔍 GameAudioEngine2.swift:175 - streamDescription: Creating stream description - Rate: 44100.0, Channels: 2, Bits: 16
🔍 GameAudioEngine2.swift:365 - updateSampleRateConversion(): Successfully connected through converter chain

### SNES via SNES9X

Notes: Sounds fine

Logs:
🔍 GameAudioEngine2.swift:175 - streamDescription: Creating stream description - Rate: 44100.0, Channels: 2, Bits: 16
🔍 GameAudioEngine2.swift:219 - updateSourceNode(): Using format: <AVAudioFormat 0x305bba170:  2 ch,  44100 Hz, Int16, interleaved>
🔍 GameAudioEngine2.swift:238 - updateSourceNode(): Attached new source node
🔍 GameAudioEngine2.swift:240 - updateSourceNode(): Exiting updateSourceNode
🔍 GameAudioEngine2.swift:175 - streamDescription: Creating stream description - Rate: 44100.0, Channels: 2, Bits: 16
🔍 GameAudioEngine2.swift:313 - updateSampleRateConversion(): Source rate: 44100.0, Target rate: 48000.0
🔍 GameAudioEngine2.swift:175 - streamDescription: Creating stream description - Rate: 44100.0, Channels: 2, Bits: 16
🔍 GameAudioEngine2.swift:314 - updateSampleRateConversion(): Source format: <AVAudioFormat 0x305bbb480:  2 ch,  44100 Hz, Int16, interleaved>, Output format: <AVAudioFormat 0x305bba260:  2 ch,  48000 Hz, Float32, deinterleaved>
🔍 GameAudioEngine2.swift:324 - updateSampleRateConversion(): Setting sample rate conversion ratio: 1.0884354
🔍 GameAudioEngine2.swift:342 - updateSampleRateConversion(): Connecting with converter format: <AVAudioFormat 0x305bba580:  2 ch,  44100 Hz, Float32, deinterleaved>
🔍 GameAudioEngine2.swift:175 - streamDescription: Creating stream description - Rate: 44100.0, Channels: 2, Bits: 16
🔍 GameAudioEngine2.swift:175 - streamDescription: Creating stream description - Rate: 44100.0, Channels: 2, Bits: 16
🔍 GameAudioEngine2.swift:365 - updateSampleRateConversion(): Successfully connected through converter chain
🔍 PVMediaCache.swift:292 - image(forKey:completion:): Image found in memory cache: true
🔍 PVMediaCache.swift:292 - image(forKey:completion:): Image found in memory cache: true
🔍 GameAudioEngine2.swift:203 - updateSourceNode(): Entering updateSourceNode
🔍 GameAudioEngine2.swift:207 - updateSourceNode(): Detached existing source node
🔍 GameAudioEngine2.swift:175 - streamDescription: Creating stream description - Rate: 44100.0, Channels: 2, Bits: 16
🔍 GameAudioEngine2.swift:219 - updateSourceNode(): Using format: <AVAudioFormat 0x305b09450:  2 ch,  44100 Hz, Int16, interleaved>
🔍 GameAudioEngine2.swift:238 - updateSourceNode(): Attached new source node
🔍 GameAudioEngine2.swift:240 - updateSourceNode(): Exiting updateSourceNode
🔍 GameAudioEngine2.swift:266 - connectNodes(): Entering connectNodes
🔍 GameAudioEngine2.swift:273 - connectNodes(): Output format: <AVAudioFormat 0x305b094a0:  2 ch,  48000 Hz, Float32, deinterleaved>
🔍 GameAudioEngine2.swift:297 - connectNodes(): Connected with format conversion: <AVAudioFormat 0x305b09450:  2 ch,  44100 Hz, Int16, interleaved> -> <AVAudioFormat 0x305b09c20:  2 ch,  44100 Hz, Float32, deinterleaved>
🔍 GameAudioEngine2.swift:304 - connectNodes(): Set main mixer node output volume to 1.0
🔍 GameAudioEngine2.swift:305 - connectNodes(): Exiting connectNodes

## RetroArch Core Options (Per-Game .opt Files)

Provenance supports RetroArch's native per-game core options system using `.opt` files. This allows individual games to have their own core option overrides.

### Path Convention

RetroArch stores core options in the following locations:

```
<Documents>/RetroArch/config/<core_name>/<core_name>.opt    # Per-core global options
<Documents>/RetroArch/config/<core_name>/<game_name>.opt    # Per-game override
```

- `core_name`: The libretro core's library name (e.g., "Nestopia", "Snes9x", "Beetle PSX")
- `game_name`: The ROM filename without extension (e.g., "Super Mario World" for "Super Mario World.smc")

### Implementation Details

The `PVRetroArchCoreBridge` class provides methods to access these paths:

- `+perGameOptionsPathForGame:` - Returns the path to a per-game `.opt` file
- `+perCoreOptionsPath` - Returns the path to the per-core global `.opt` file
- `+coreLibraryName` - Returns the core's library name as reported by libretro

For Swift UI integration, use `RetroArchCoreOptionsFileHelper` which provides:

- `readOptFile(atPath:)` - Reads an `.opt` file and returns key-value pairs
- `writeOptFile(options:toPath:)` - Writes options to an `.opt` file
- `mergeOptions(intoOptFileAtPath:)` - Merges new options into an existing file
- `deleteOptFile(atPath:)` - Deletes an `.opt` file

### .opt File Format

RetroArch `.opt` files are simple text files with the following format:

```
# RetroArch Core Options
# Generated by Provenance

nestopia_blargg_ntsc_filter = "disabled"
nestopia_aspect_ratio = "auto"
nestopia_fds_auto_insert = "enabled"
```

Each line represents a core option in `key = "value"` format. Lines starting with `#` are comments.

### Important Notes

1. **ROM Filename Matching**: The game name used for the `.opt` filename is derived from the ROM path's basename (filename without directory or extension). If Provenance renames or relocates ROMs, the `.opt` file must be renamed accordingly.

2. **Core Library Name**: The core name used in the path comes from the libretro core's `library_name` field (e.g., "Nestopia" not "PVNestopiaCore"). This is obtained at runtime from the loaded core.

3. **Config Directory**: The base config directory (`<Documents>/RetroArch/config`) is determined by RetroArch's path system via `APPLICATION_SPECIAL_DIRECTORY_CONFIG`.

4. **File Creation**: RetroArch creates `.opt` files automatically when core options are changed and `game_specific_options` is enabled in the configuration (which is the default in Provenance).

## Extending the Artwork Pipeline

The artwork pipeline lives in `PVLookup` (Tier 5). `PVLookup.shared` is the single entry point; it fans out to multiple database back-ends, merges their results, sorts by type priority, and caches the final list.

### Architecture Overview

```
PVLookup.shared (actor)
├── OpenVGDB          (offline SQLite — ArtworkLookupOfflineService)
├── libretrodb        (offline SQLite + remote thumbnails — ArtworkLookupOfflineService)
└── TheGamesDB        (offline SQLite index + remote CDN URLs — ArtworkLookupService)
```

All three back-ends are queried **in parallel** via `withTaskGroup`. Results are concatenated in source order (OpenVGDB → LibretroDB → TheGamesDB), then sorted by `ArtworkType` priority.

### `ArtworkType` OptionSet

`ArtworkType` is a `UInt`-backed `OptionSet` defined in `PVLookup/Sources/PVLookupTypes/ArtworkType.swift`:

| Case | Raw bit | Display name |
|------|---------|--------------|
| `.boxFront` | `1 << 0` | Box Front |
| `.boxBack` | `1 << 1` | Box Back |
| `.manual` | `1 << 2` | Manual |
| `.screenshot` | `1 << 3` | Screenshot |
| `.titleScreen` | `1 << 4` | Title Screen |
| `.fanArt` | `1 << 5` | Fan Art |
| `.banner` | `1 << 6` | Banner |
| `.clearLogo` | `1 << 7` | Clear Logo |
| `.other` | `1 << 8` | Other |

Composite constants:
- `.defaults` — `[.boxFront, .titleScreen, .boxBack]` — used when no type filter is supplied
- `.retroDBSupported` — `[.boxFront, .titleScreen, .screenshot]` — the subset LibretroDB thumbnails can provide

#### Per-source type support

| Source | boxFront | boxBack | screenshot | titleScreen | fanArt | banner | clearLogo | manual | other |
|--------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **OpenVGDB** | ✅ | ✅ | ✅ | — | — | — | — | — | ✅ |
| **LibretroDB** | ✅ | — | ✅ | ✅ | — | — | — | — | — |
| **TheGamesDB** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | ✅ |

OpenVGDB infers type from URL path keywords (`"front"` → `.boxFront`, `"back"` → `.boxBack`, `"screenshot"` → `.screenshot`); other artwork URLs (for example, cart/disc covers) fall back to `.other`.
LibretroDB maps its three thumbnail directories: `named_boxarts/` → `.boxFront`, `named_titles/` → `.titleScreen`, `named_snaps/` → `.screenshot`.
TheGamesDB maps its `type`/`side` columns via `ArtworkType(fromTheGamesDB:side:)`; several logical artwork types (including manuals) are currently collapsed to `.other` rather than emitting `.manual`.

### `ArtworkSearchCache` — LRU cache

`ArtworkSearchCache` is a Swift `actor` singleton (`ArtworkSearchCache.shared`) backed by a `[ArtworkSearchKey: [ArtworkMetadata]]` dictionary, defined in `PVLookup/Sources/PVLookupTypes/ArtworkSearchCache.swift`.

- **Capacity**: 100 entries (`maxCacheSize = 100`).
- **Eviction**: Least-recently-used. Access order is tracked in an `accessOrder: [ArtworkSearchKey]` array. On every cache hit the key is moved to the end; on overflow the first (oldest) key is removed.
- **Cache key** (`ArtworkSearchKey`): composite of `gameName` (case-insensitive, compared using `lowercased()`), `systemID: SystemIdentifier?`, and `artworkTypes: ArtworkType`. Two keys are equal when all three fields match (name comparison is case-insensitive).
- **Writes**: `PVLookup.searchArtwork(byGameName:systemID:artworkTypes:)` writes to the cache after a successful search. A result is only cached when it is non-empty.
- **Invalidation**: Call `ArtworkSearchCache.shared.clear()` to flush the entire cache (e.g., after a library rescan).

### Source ranking and result merging

After the parallel task group completes, results are combined in this fixed order:

```
openVGDBArtwork + libretroDBArtwork + theGamesDBartwork
```

The combined array is then sorted by type priority (highest first):

```
boxFront → boxBack → screenshot → titleScreen → clearLogo → banner → fanArt → manual → other
```

This sort is performed by `PVLookup.sortArtworkByType(_:)`, which only compares type priority. Relative ordering of artwork items with the same type is not guaranteed by this sort; if you need a deterministic secondary ordering (for example, preferring OpenVGDB over LibretroDB over TheGamesDB), apply an additional stable sort or explicitly sort by a composite key such as `(typePriority, sourceRank)` at the call site.

### Deduplication strategy

`ArtworkMetadata` is `Hashable` by `(url, type, source)`. Individual back-ends or helper types may perform their own internal deduplication using `Set<ArtworkMetadata>` (for example, the `LibretroArtwork.searchArtwork(byGameName:systemID:artworkTypes:)` helper can do this when used directly). The LibretroDB code path that `PVLookup` currently uses (`libretrodb.searchArtwork(...)` in `libretrodb.swift`) does **not** perform `Set`-based deduplication. The merged result from `PVLookup` is **not** additionally deduplicated at the aggregation layer, so distinct sources can return the same artwork URL as long as `source` differs.

> Note: Converting the result array to a `Set<ArtworkMetadata>` only removes exact `(url, type, source)` duplicates. If you need **global** deduplication across sources (e.g. by URL or by `(url, type)`), build a dictionary keyed by your desired key and then take the values, for example:
>
> ```swift
> let byURL = Dictionary(artworks.map { ($0.url, $0) }, uniquingKeysWith: { first, _ in first })
> let globallyDedupedByURL = Array(byURL.values)
> ```
>
> or, if you need `(url, type)` as the key:
>
> ```swift
> let byURLAndType = Dictionary(artworks.map { (($0.url, $0.type), $0) }, uniquingKeysWith: { first, _ in first })
> let globallyDedupedByURLAndType = Array(byURLAndType.values)
> ```

### Adding a new artwork source

#### 1. Conform to `ArtworkLookupService`

Create a new type that conforms to `ArtworkLookupService`. If your source also needs to expose a mapping from logical artwork types to its own identifiers (e.g. size or variant codes), additionally conform to `ArtworkLookupOnlineService` and implement `getArtworkMappings()`. The choice of protocol is about capabilities, not whether the source is online or offline:

```swift
// PVLookup/Sources/MyNewDB/MyNewDB.swift
import PVLookupTypes
import PVSystems

public struct MyNewDB: ArtworkLookupService {

    public func searchArtwork(
        byGameName name: String,
        systemID: SystemIdentifier?,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        // Query your data source and return ArtworkMetadata values.
        // Use `source: "MyNewDB"` so duplicates from other sources are kept distinct.
        return nil
    }

    public func getArtwork(
        forGameID gameID: String,
        artworkTypes: ArtworkType?
    ) async throws -> [ArtworkMetadata]? {
        return nil
    }

    public func getArtworkURLs(forRom rom: ROMMetadata) async throws -> [URL]? {
        return nil
    }
}
```

For sources that also provide ROM-to-artwork mapping tables, additionally conform to `ArtworkLookupOfflineService` (for fully offline sources) or `ArtworkLookupOnlineService` (for sources that require an online connection). As of now, both protocols simply add `getArtworkMappings() async throws -> ArtworkMapping` and are distinguished by their connectivity semantics.

#### 2. Register the source in `PVLookup`

Open `PVLookup/Sources/PVLookup/PVLookup.swift` and make four edits:

**a. Add a case to `LocalDatabases`:**

```swift
public enum LocalDatabases: CaseIterable {
    // ... existing cases ...
    case myNewDB
}
```

**b. Add a stored property to `PVLookup`:**

```swift
private var myNewDB: MyNewDB?
```

**c. Initialize it in `initializeDatabases()`:**

```swift
do {
    let db = try await MyNewDB()
    self.myNewDB = db
} catch {
    ELOG("Failed to initialize MyNewDB: \(error)")
}
```

**d. Query it in `searchArtwork(byGameName:systemID:artworkTypes:)` and `getArtwork(forGameID:artworkTypes:)`:**

```swift
let shouldSearchMyNewDB = databases.contains(.myNewDB)
var myNewDBArtwork: [ArtworkMetadata] = []

// Inside the existing withTaskGroup block:
group.addTask {
    guard shouldSearchMyNewDB else { return (3, []) }
    if let results = try? await self.myNewDB?.searchArtwork(
        byGameName: name,
        systemID: systemID,
        artworkTypes: artworkTypes
    ) {
        return (3, results)
    }
    return (3, [])
}

// In the for-await loop:
case 3: myNewDBArtwork = result

// In the combine step:
let results = openVGDBArtwork + libretroDBArtwork + theGamesDBartwork + myNewDBArtwork
```

Also add it to the default `databases` array and to `getArtworkURLs(forRom:)` / `getArtworkMappings()` if applicable.

#### 3. Gate behind a feature flag (optional)

If your source is experimental, add a case to `PVFeature` in `PVFeatureFlags/Sources/PVFeatureFlags/PVFeatureFlags.swift`:

```swift
/// Enables artwork lookup from MyNewDB.
/// Disabled by default until the data set is validated.
case myNewDBArtwork = "myNewDBArtwork"
```

Then guard initialization and the `databases.contains(.myNewDB)` check with the flag:

```swift
// In initializeDatabases():
guard await PVFeatureFlags.shared.isEnabled(.myNewDBArtwork) else { return }

// In the databases array initializer:
private var databases: [LocalDatabases] = {
    var dbs: [LocalDatabases] = [.libretro, .openVGDB, .theGamesDB]
    // myNewDB added at runtime after flag check
    return dbs
}()
```

Alternatively, check the flag inside the `group.addTask` closure so the query is skipped at search time rather than at initialization time.

#### 4. Add the `SPM` module target

If your source lives in a new Swift package target, add it to `PVLookup/Package.swift`:

```swift
.target(
    name: "MyNewDB",
    dependencies: ["PVLookupTypes", "PVSQLiteDatabase", "PVSystems", "PVLogging"],
    path: "Sources/MyNewDB"
),
```

And add it as a dependency of the `PVLookup` target:

```swift
.target(
    name: "PVLookup",
    dependencies: [
        // ... existing dependencies ...
        .target(name: "MyNewDB"),
    ],
    ...
),
```

Use `#if canImport(MyNewDB)` guards in `PVLookup.swift` to keep the module optional (matching the pattern used for OpenVGDB, libretrodb, TheGamesDB, and ShiraGame).
