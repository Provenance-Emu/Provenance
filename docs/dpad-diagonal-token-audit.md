# D-Pad Diagonal Token Audit (issue #2611)

## Token routing summary

`DeltaSkinView` (`PVUI/Sources/PVUIBase/SwiftUI/DeltaSkins/Views/DeltaSkinView.swift`) collects raw cardinal directions (`up`/`down`/`left`/`right`) from the touch position relative to the D‑pad button center. `resolveDiagonalDirections(_:forButton:)` (lines 2383–2415) then promotes a cardinal pair to a diagonal token (`upleft`/`upright`/`downleft`/`downright`) **iff the skin's button mapping has a key for that diagonal**. Otherwise it leaves the two cardinals in place. Each token in the resolved set is forwarded one at a time to `DeltaSkinInputHandler.buttonPressed(_:)` / `buttonReleased(_:)`.

The handler has two delivery paths and tries them in order:

1. **`trySystemResponderCall`** (line 1803) — direct path: `let b = PV<System>Button(id); responder.didPush(b, ...)`. The handler runs `normalizeSkinButtonId` first but the per‑system normalizers do **not** rewrite diagonal tokens, so `id` reaches `PV<System>Button.init(_:String)` as `"upleft"`/`"upright"`/`"downleft"`/`"downright"`.
2. **`forwardButtonPressToController`** (line 1389, fallback) — converts the token to `JSDPadDirection` via `stringToDirection` (lines 1670–1691) and calls `controller.dPad(_, didPress: .upLeft)`. The legacy `PV<System>ControllerViewController` overrides the `dPad(_:didPress:)` callback and explicitly decomposes diagonals into two cardinal `didPush`/`didRelease` calls (see `PVNESControllerViewController.swift:49–106`, `PVIntellivisionControllerViewController.swift:68–125`, etc.).

No `PV<System>Button` enum declares diagonal cases, and no `ResponderClient` protocol exposes a diagonal call. Cores ultimately receive only cardinal `up`/`down`/`left`/`right` `didPush`/`didRelease` events; almost every bridge stores them in a per‑direction array or a bitmask, so simultaneous `up`+`left` correctly produces an in‑game diagonal.

## The bug

When the skin emits a diagonal token (path 1), `PV<System>Button("upleft")` falls through every enum's `default:` branch. Sample of `default:` fallback values across `PVCoreBridge/Sources/PVCoreBridge/Features/Controls/`:

| Enum | `default` value (what `"upleft"` becomes) |
|------|-------------------------------------------|
| `PVNESButton`, `PVSNESButton`, `PVGBButton`, `PVGBAButton`, `PVPSXButton`, `PVPS2Button`, `PVPSPButton`, `PVDreamcastButton`, `PVN64Button` (`.dPadUp`), `PVDOSButton`, `PV3DOButton`, `PV3DSButton`, `PV5200Button`, `PV7800Button`, `PVColecoVisionButton`, `PVDoomButton`, `PVDSButton`, `PVEP128Button`, `PVIntellivisionButton`, `PVLynxButton`, `PVMAMEButton`, `PVMSXButton`, `PVNeoGeoButton`, `PVNGPButton`, `PVOdyssey2Button`, `PVPCEButton`, `PVPCECDButton`, `PVPCFXButton`, `PVSaturnButton`, `PVSega32XButton`, `PVSG1000Button`, `PVSupervisionButton`, `PVTIC80Button`, `PVWolf3DButton`, `PVWSButton` | `.up` (or `.dPadUp`) |
| `PV2600Button` | `.fire1` |
| `PVA8Button` | `.count` |
| `PVCDiButton` | `.button1` |
| `PVGenesisButton`, `PVMasterSystemButton` | `.b` |
| `PVGCButton` | `.a` |
| `PVPMButton` (PokéMini) | `.menu` |
| `PVVBButton` | `.leftUp` |

So if a skin's mapping contains an `upleft` key, **the diagonal half is dropped at `PV<System>Button.init`**: the user holding north‑west on screen produces a single `.up` press (or worse — a stray `.b`/`.fire1`/`.menu` event for a few systems) instead of the two‑cardinal combo every core actually consumes.

Path 2 (the controller‑VC fallback) is correct, but it only runs when `trySystemResponderCall` returns `false` (i.e. the core does not conform to the per‑system responder protocol). Every active native + RetroArch core conforms, so path 1 wins in practice.

## Per‑core verdict

Every bridge surveyed is a cardinal‑only consumer (per‑direction byte / bitmask / boolean). The risk is identical for all of them and lives at the `PV<System>Button.init` step, not in the bridge. The verdict column below reflects whether the core can suffer a diagonal drop **when a skin defines diagonal keys** (issue #2611 condition).

| System / core | Bridge file | D‑pad handling style | Verdict |
|---------------|-------------|----------------------|---------|
| NES (FCEU) | `Cores/FCEU/PVFCEUEmulatorCore+Controls.mm:50–60` | Bitmask OR via `NESMap`, packs 4 players into 2 ports | ⚠️ may drop diagonals (path 1) |
| NES / SNES / GB / GBA / Genesis / 32X / Saturn / PSX / VirtualBoy / WonderSwan / Lynx / NGP / PCE / PCFX (Mednafen) | `Cores/Mednafen/Sources/MednafenGameCoreBridge/MednafenGameCoreBridge+Controls.mm` | `inputBuffer[player][0] \|= 1 << mapped` per direction | ⚠️ may drop diagonals (path 1) |
| Genesis / SegaCD / SG‑1000 (Genesis‑Plus‑GX) | `Cores/Genesis-Plus-GX/Sources/PVCoreGenesisPlusBridge/PVCoreGenesisPlusBridge.m:890–904` | `_pad[player][button] = 1` (SG1000 remapped via `SG1000Map`) | ⚠️ may drop diagonals (path 1) |
| Sega 32X (PicoDrive) | `Cores/PicoDrive/Sources/PVPicoDriveBridge/PVPicoDriveBridge.m:925–931` | `_pad[player][button] = 1` | ⚠️ may drop diagonals (path 1) |
| N64 (Mupen) | `Cores/Mupen64Plus/Sources/PVMupenBridge/PVMupenBridge+Controls.m:458–464` | `padData[player][button] = 1` | ⚠️ may drop diagonals (path 1) |
| Atari 800 / 5200 | `Cores/Atari800/Sources/PVAtari800Bridge/PVAtari800Bridge.m:659–810` | Per‑direction flags on `controllerStates[player]` | ⚠️ may drop diagonals (path 1) |
| Atari 7800 (ProSystem) | `Cores/ProSystem/Sources/PVProSystemBridge/PVProSystemCoreBridge.mm` | Per‑direction flags | ⚠️ may drop diagonals (path 1) |
| Atari 2600 (Stella) | bundled via `PVCoreBridgeRetro` | RetroArch joypad bitmask | ⚠️ may drop diagonals (path 1) |
| Dreamcast (Reicast / Flycast) | `Cores/Reicast/PVReicastCore/Core/PVReicastCore+Controls.mm:142–162`; `Cores/Flycast/.../PVFlycastCore+Controls.mm` | `kcode[player]` bitmask | ⚠️ may drop diagonals (path 1) |
| GameCube / Wii (Dolphin) | `Cores/Dolphin/PVDolphinCore/Core/PVDolphinCore+Controls.mm` | Per‑button state stored | ⚠️ may drop diagonals (path 1) |
| 3DS (Citra / emuThree / Azahar) | `Cores/Citra/PVAzaharCore/Core/PVAzaharCoreBridge+Controls.mm`; `Cores/emuThree/PVEmuThreeCore/Core/PVEmuThreeCoreBridge+Controls.mm` | Per‑button state into HID service | ⚠️ may drop diagonals (path 1) |
| DS (DeSmuME / melonDS) | `Cores/Desmume2015/PVDesmume2015Core/Core/PVDesmume2015Core+Controls.mm`; `Cores/melonDS/PVMelonDSCore/Core/PVMelonDSCore+Controls.mm` | NDS register bitmask | ⚠️ may drop diagonals (path 1) |
| PSP (PPSSPP) | `Cores/PPSSPP/PVPPSSPPCore/Core/PVPPSSPPCore+Controls.mm` | Bitmask | ⚠️ may drop diagonals (path 1) |
| PSX (DuckStation) | `Cores/DuckStation/PVDuckStation/Source/PVDuckStationCoreBridge.mm` | Bitmask | ⚠️ may drop diagonals (path 1) |
| PS2 (Play!) | `Cores/Play/PVPlayCore/Core/PVPlayCore+Controls.mm` | Per‑button state | ⚠️ may drop diagonals (path 1) |
| MAME (FinalBurnNeo / mame4iOS) | `CoresRetro/RetroArch/...` | RA joypad bitmask | ⚠️ may drop diagonals (path 1) |
| MSX (fmsx / blueMSX) | `Cores/fmsx/PVfMSXCore/PVfMSXCoreBridge.mm` | Per‑button | ⚠️ may drop diagonals (path 1) |
| GB (Gambatte / SameBoy / TGBDual) | `Cores/Gambatte/...`; `Cores/TGBDual/Sources/PVTGBDualBridge/PVTGBDualBridge+Controls.mm` | Bitmask | ⚠️ may drop diagonals (path 1) |
| ColecoVision (Gearcoleco) | RetroArch bridge | Bitmask | ⚠️ may drop diagonals (path 1) |
| PokéMini | `Cores/PokeMini/Sources/PVPokeMiniBridge/PVPokeMiniBridge.m:393–399` | Per‑button state | ⚠️ may drop diagonals (path 1) — diagonals are **meaningless** on PokéMini hardware (no diagonal input physically possible), so risk is theoretical |
| Vectrex (VecX) | `Cores/VecX/Sources/PVVecX/PVVecXCore+Controls.mm:142–152` | Stub (commented out — input not yet wired) | ❓ N/A — input handler is empty |
| Intellivision (FreeIntv) | `Cores/FreeIntv/PVFreeIntvCore/PVFreeIntvCore.mm` | Pure libretro joypad bitmask, core composes its 16‑direction disc internally | ⚠️ may drop diagonals (path 1). Disc emulation relies on simultaneous cardinals — losing one half cuts the disc to 8 directions. |
| Atari Jaguar (VirtualJaguar) | `CoresRetro/RetroArch/PVRetroArchCore/Core/PVRetroArchCore+Controls+Jaguar.m` | RA joypad bitmask | ⚠️ may drop diagonals (path 1) |
| ZX Spectrum (fuse) | `Cores/fuse/...` | Per‑button state via libretro | ⚠️ may drop diagonals (path 1) |
| Doom (PrBoom) | RetroArch core | Bitmask + special `PVDoomButton(id)` parser | ⚠️ may drop diagonals (path 1) |
| Other libretro cores under `Cores/` and `CoresRetro/` (4DO, Bliss, CrabEMU, ep128emu, fuse, GameMusicEmu, hatari, JollyGoodEmulation, NP2Kai, O2EM, opera, pcsx_rearmed, ProSystem, Reicast, sm64ex, snes9x, snesticle, supergrafx, TIC80) | various `+Controls.mm` / RA bridge | All are cardinal‑only consumers (bitmask or per‑direction byte). | ⚠️ may drop diagonals (path 1) |

> The verdict is **uniform** because the failure point is the per‑system button enum init, not the bridge. Every core listed handles two simultaneous cardinals correctly; none can interpret a diagonal token.

## Action items

The fix is **not** per‑core. There are three viable spots, ranked by minimal blast radius:

1. **Cheapest fix — `DeltaSkinInputHandler.normalizeSkinButtonId(_:for:)`** (`PVUI/Sources/PVUIBase/SwiftUI/DeltaSkins/Models/DeltaSkinInputHandler.swift:2204`): when `s` is `"upleft"`/`"upright"`/`"downleft"`/`"downright"`, split the press/release into two cardinal `forwardButtonPress` calls instead of normalizing in place. Because `normalizeSkinButtonId` returns a single `String`, this would actually need a small refactor at the caller in `trySystemResponderCall` (lines 1803‑onward) — when it sees a diagonal token, fan out to two `PV<System>Button(id)` calls (`"up"`+`"left"`, etc.).
2. **Defensive fix — `DeltaSkinView.resolveDiagonalDirections`** (`PVUI/Sources/PVUIBase/SwiftUI/DeltaSkins/Views/DeltaSkinView.swift:2383–2415`): never collapse cardinals into a diagonal token. Always emit `up`+`left` even when the skin mapping has an `upleft` key. This loses any per‑skin custom diagonal command (rare/unused in practice — the diagonal entries in real skins all map to game commands that are themselves combos), but it eliminates the routing hazard in one line.
3. **Hardening fix — every `PV<System>Button.init(_:String)`** in `PVCoreBridge/Sources/PVCoreBridge/Features/Controls/PV*Button.swift`: explicit cases for `"upleft"`/`"upright"`/`"downleft"`/`"downright"` returning `.up` and a sibling cardinal would still need plumbing because `init` returns a single value. Not viable as a standalone fix — would need a new `init(_:String) -> [Self]` API and a refactor of every caller.

Recommended: **Action item 1**. One file changed (`DeltaSkinInputHandler.swift`), surgical diff, no behavior change for any skin that already lacks diagonal keys.

Optional follow‑up: add a unit test in `PVCoreBridge` that asserts each `PV<System>Button.init("upleft")` is **not** silently swallowed (e.g. introduce a fallible `init?` variant, or assert the current implementation's contract).

## Files referenced

- `/Users/jmattiello/Workspace/Provenance/Provenance/PVUI/Sources/PVUIBase/SwiftUI/DeltaSkins/Views/DeltaSkinView.swift` — `resolveDiagonalDirections` (2383–2415); call sites 1657, 1786, 1830
- `/Users/jmattiello/Workspace/Provenance/Provenance/PVUI/Sources/PVUIBase/SwiftUI/DeltaSkins/Models/DeltaSkinInputHandler.swift` — entry points 110, 293; `forwardButtonPress` 1693; `trySystemResponderCall` 1803; `stringToDirection` 1669–1691; `normalizeSkinButtonId` 2204; canonical token list 1363, 1472, 1680–1687, 2545, 2835
- `/Users/jmattiello/Workspace/Provenance/Provenance/PVUI/Sources/PVUIBase/Controller/OSD/JSDPad.swift` — `JSDPadDirection` enum (18–28); `delegate.dPad(self, didPress/Release:)` (33–36)
- `/Users/jmattiello/Workspace/Provenance/Provenance/PVUI/Sources/PVUIBase/Controller/Systems/PVNESControllerViewController.swift:49–106` — reference legacy diagonal decomposer
- `/Users/jmattiello/Workspace/Provenance/Provenance/PVUI/Sources/PVUIBase/Controller/Systems/PVIntellivisionControllerViewController.swift:68–125`
- `/Users/jmattiello/Workspace/Provenance/Provenance/PVCoreBridge/Sources/PVCoreBridge/Features/Controls/PV*Button.swift` — every `init(_:String)` falls through `default:` for diagonal tokens
