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
| Azahar / Citra (3DS) | `.requiredOrCrash` | Hard crash without JIT when `enableJIT=true` |
| emuThree (3DS) | `.requiredOrCrash` | Same Citra codebase; same JIT requirement |

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
open override var jitRequirement: PVJITRequirement {
    .optional(fallback: "Interpreter")
}
```

The default implementation returns `.notSupported`, so only JIT-capable cores need to override.

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
