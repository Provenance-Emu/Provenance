# DEVELOPER.md

__Developers should start here first for breif instructions for building and working with the source code__

## Documentation

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
