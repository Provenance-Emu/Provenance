# Console-Style Default Overlays for Every System — Design

**Date:** 2026-10-09
**Status:** Proposed
**Builds on:** `2026-10-07-programmatic-touch-overlay-design.md` (the engine, Phase 1). This spec adds no engine features except where §4 says so; it is mostly data.

## 1. Why

The programmatic overlay (`PVTouchOverlay`) draws a console-styled pad for 14 systems
(NES, GB, GBC, SNES, GBA, Genesis, 32X, Sega CD, N64, PSX, GameCube, Wii, DS, 3DS).
Every other system falls back to the legacy SwiftUI `DefaultControllerSkinView`: the
purple-bottomed generic pad that mis-sizes screens, breaks touch for dual-screen cores
and looks nothing like the hardware. The maintainer wants the GameCube treatment for
everything: a pad that reads as the original controller at a glance, correct screen
placement, working touch, no per-system special cases in the view controller.

## 2. Decisions

1. **Every shipping system gets a binding.** When this lands, `SystemOverlayBindings.binding(for:)`
   returns non-nil for every `SystemIdentifier` that has a core, and
   `DefaultControllerSkinView` is no longer reachable on iOS. It is deleted in the
   engine's Phase 2 as already planned.
2. **A binding is data: family + tokens + labels + palette + switches.** New hardware
   shapes get a family; new brands get a palette. Nothing else is per-system.
3. **Tokens are the skin vocabulary** `DeltaSkinInputHandler` already resolves per system
   (`PV<System>Button(id)`). A binding may only use tokens that handler resolves for its
   system; §5 lists the gaps and fixes them in the handler, not with overlay-only names.
4. **Computers and arcade boards get a pad, not a keyboard.** The on-screen keyboard,
   mouse and keypad helpers already exist (`PVControllerViewController` toggles). The
   overlay gives them the pad their core maps to the joypad plus a keyboard toggle
   action; full keyboard art is out of scope.
5. **Screens come from the engine's screen policy**, never from the binding. Dual-screen
   and odd-aspect systems only pick a policy (`topBand`, `centerColumn`, `dualStacked`,
   `dualStacked3DS`, `fill`); the planner sizes the screen from the core's aspect.
6. **Palettes are the console's shell and button colours**, flat, no gradients. One palette
   per brand generation; systems in the same generation share it (see §3.3).

## 3. Coverage

### 3.1 Families (existing, reused as-is)

| Family | Slots | Used for |
|---|---|---|
| TwoButton | a b start select | NES, GB, GBC, FDS, Game Gear, Master System, SG-1000, Pokémon Mini, Supervision, WonderSwan, WS Color, Mega Duck, NGP, NGPC, Odyssey², Vectrex (+ 4-button variant §3.2) |
| ThreeFace | a b c start | Genesis "3-button" subtype only |
| FourFace | a b x y l r start select | SNES, DS, 3DS (via DS/N3DS pad), PC Engine 6-button? no (see SixFace), Virtual Boy (dual dpad §3.2), Lynx (§3.2) |
| SixFace | a b c x y z start select | Genesis, 32X, Sega CD, Saturn, Neo Geo, Neo Geo CD, CPS1/2/3, MAME, NAOMI, NAOMI 2, Atomiswave, Dreamcast arcade subtype |
| GBA | a b l r start select | GBA |
| DigitalPad | a b x y l r l2 r2 start select | PSX digital, PS2 digital, PSP, PCE/SGFX/PCE-CD 2-button (hidden slots), PC-FX, CD-i, Jaguar face buttons, DOS/DOOM/Wolf3D/Quake/Quake 2, TIC-80 |
| DualStick | DigitalPad + l3 r3 | PSX DualShock, PS2, PS3 |
| N64 / GameCube / WiiRemote / WiiClassic / WiiRemoteSideways / DSPad / N3DSPad | as today | unchanged |

### 3.2 New families (engine work, §4)

| Family | Slots | Shape | Systems |
|---|---|---|---|
| **Keypad** | TwoButton or FourFace slots + 12-key keypad (`k1`…`k9`, `k0`, `kStar`, `kPound`) | Face pad on the right, a 3×4 keypad toggled by a `keypad` action on the left under the d-pad | Atari 5200, Intellivision, ColecoVision, Jaguar, Jaguar CD, Atari 7800 (2 keys only: pause/select) |
| **ArcadeStick** | a b c x y z start select (+ `coin`) | Ball-top stick on the left (`stick` control drawn as a large circle, 8-way digital), six buttons in two arcade rows, Start and Coin above | MAME, CPS1/2/3, Neo Geo, Neo Geo CD, NAOMI, NAOMI 2, Atomiswave; also the "arcade" subtype of Dreamcast |
| **Paddle** | a b + `paddle` | Single fire button and a horizontal slider mapped to the analog axis | Atari 2600 paddle subtype only (joystick is the default: TwoButton with one button) |
| **DualDPad** | a b l r start select + second dpad | Virtual Boy: two d-pads, two face buttons under the right one | Virtual Boy |
| **Handheld landscape** | existing slots | Not a family: a `landscapeOnly` flag on a binding that hides the portrait template and rotates the screen policy to `centerColumn` | Lynx (`flip` action for Lynx's rotated games), WonderSwan (vertical mode) |

### 3.3 Palettes

| Palette | Shell / primary / secondary / dpad | Systems |
|---|---|---|
| `nes` (exists) | grey / red A / red B | NES, FDS |
| `gameBoy` (exists) | cream / magenta | GB, GBC, GBA, Pokémon Mini, Supervision, Mega Duck |
| `snes` (exists) | lavender grey / coloured ABXY | SNES, Virtual Boy (override: red/black) |
| `n64`, `gameCube`, `wii`, `ds`, `playStation` (exist) | as today | N64; GC; Wii; DS, 3DS; PSX, PS2, PS3, PSP |
| `genesis` (exists) | black / grey | Genesis, 32X, Sega CD, Master System, SG-1000, Game Gear |
| **`saturn`** | charcoal / grey face, blue Saturn ring hint on Start | Saturn |
| **`dreamcast`** | white / red A, blue B, green Y, yellow X (DC face colours) | Dreamcast, NAOMI, NAOMI 2, Atomiswave |
| **`neoGeo`** | black / red A, yellow B, green C, blue D | Neo Geo, Neo Geo CD |
| **`capcom`** | blue cabinet / white buttons, red Start | CPS1/2/3 |
| **`arcade`** | black cabinet / red white blue green yellow pink buttons | MAME |
| **`atari`** | woodgrain brown / orange fire, black keypad | 2600, 5200, 7800, 8-bit, Lynx (black/orange), Jaguar, Jaguar CD, Atari ST |
| **`pcEngine`** | white / orange Run, blue Select | PCE, SGFX, PCE CD, PC-FX |
| **`neoGeoPocket`** | silver / blue | NGP, NGPC, WonderSwan, WS Color |
| **`intellivision`** | brown / gold disc, cream keypad | Intellivision |
| **`coleco`** | black / red fire, grey keypad | ColecoVision |
| **`odyssey`** | silver / black | Odyssey², Vectrex (override: black/white) |
| **`computer`** | beige / brown keys | DOS, DOOM, Wolf3D, Quake, Quake 2, C64, MSX, MSX2, Atari 8-bit, ZX Spectrum (override: black/rainbow stripe), EP128, PC-98, Macintosh, TIC-80 (override: dark/teal), PalmOS |
| **`cdi`** | black / white | CD-i |

Palette values are fixed in code review against photos, not in this spec.

### 3.4 Binding table

Subtypes in brackets are selectable in the editor (`OverlayPadKindResolver.selectableVariants`).
"Tokens" lists only where they differ from the family's defaults.

| System | Family [subtypes] | Palette | Tokens / labels / switches | Screen policy |
|---|---|---|---|---|
| Atari2600 | TwoButton [joystick (default), paddle→Paddle] | atari | a="fire", hide b; switches: `select`, `reset`, `difficulty-left`, `difficulty-right`, `color-bw` | topBand |
| Atari5200 | Keypad | atari | fire1 fire2, keypad 0-9 * #, start pause reset | topBand |
| Atari7800 | TwoButton | atari | a="fire1" b="fire2"; switches `select`, `reset`, `pause` | topBand |
| Atari8bit | TwoButton | computer | fire, start select option | topBand |
| AtariJaguar, AtariJaguarCD | Keypad (FourFace slots: A B C + option pause) | atari | keypad 0-9 * # | topBand |
| AtariST | TwoButton | computer | fire; action `keyboard`, `mouse` | fill |
| Lynx | FourFace (l/r hidden) + action `flip` | atari | a="a" b="b" option1 option2 | centerColumn, landscapeOnly |
| C64, MSX, MSX2, EP128, ZXSpectrum, PC98, Macintosh, PalmOS | TwoButton | computer | fire; actions `keyboard`, `mouse` | fill |
| DOS, DOOM, Wolf3D, Quake, Quake2 | DigitalPad [pad (default), dualStick→DualStick] | computer | actions `keyboard`, `mouse` | fill |
| TIC80 | DigitalPad | computer | a b x y | centerColumn |
| ColecoVision | Keypad | coleco | fire-left fire-right, keypad | topBand |
| Intellivision | Keypad | intellivision | disc as dpad, top/left/right side buttons as a b c, keypad | topBand |
| Odyssey2 | TwoButton | odyssey | action; action `keyboard` | topBand |
| Vectrex | FourFace (l/r hidden) | odyssey (black) | 1 2 3 4 | centerColumn (portrait screen) |
| CDi | DigitalPad | cdi | 1 2 as a b | topBand |
| NES, FDS | TwoButton | nes | (FDS: + action `disk-side`) | topBand |
| GB, GBC, MegaDuck, Supervision, PokemonMini | TwoButton | gameBoy | | topBand |
| GameGear, MasterSystem, SG1000 | TwoButton | genesis | 1 2 as a b; MS: `pause` as start | topBand |
| Genesis, Sega32X, SegaCD | SixFace [6-button (default), 3-button→ThreeFace] | genesis | (exists) | topBand |
| Saturn | SixFace + l r | saturn | A B C X Y Z L R Start | topBand |
| Dreamcast | FourFace + l2 r2 analog triggers [standard, arcade→ArcadeStick] | dreamcast | A B X Y, triggers | topBand |
| NAOMI, NAOMI2, Atomiswave | ArcadeStick | dreamcast | coin start | topBand |
| NeoGeo, NeoGeoCD | ArcadeStick | neoGeo | A B C D as a b c x; coin start select | topBand |
| CPS1, CPS2, CPS3 | ArcadeStick | capcom | 6 buttons; coin start | topBand |
| MAME | ArcadeStick | arcade | 6 buttons; coin start; action `service` | topBand (rotates with vertical games via the existing SET_ROTATION path) |
| PCE, SGFX, PCECD | DigitalPad [2-button (default), 6-button→SixFace] | pcEngine | I II as a b, Run Select | topBand |
| PCFX | DigitalPad | pcEngine | I–VI, Run Select | topBand |
| NGP, NGPC | TwoButton | neoGeoPocket | A B Option | topBand |
| WonderSwan, WonderSwanColor | TwoButton + second dpad (DualDPad) [horizontal (default), vertical] | neoGeoPocket | X1-4 Y1-4 A B Start | topBand / centerColumn in vertical |
| VirtualBoy | DualDPad | snes (red/black) | A B L R Start Select | centerColumn (aspect 384:224) |
| SNES, N64, GameCube, Wii, DS, _3DS, GBA, PSX | as today | | | |
| PS2, PS3 | DualStick | playStation | | topBand |
| PSP | DigitalPad + left stick | playStation | | centerColumn (16:9) |
| RetroArch, Music | none | | not launched with an overlay | |

## 4. Engine work (the only code outside the data tables)

1. **Keypad family** with a toggled keypad group (`action(.keypad)` shows/hides a 3×4
   `button` grid; grid cells are ordinary buttons so the editor can move the group).
2. **ArcadeStick family**: an 8-way `dpad` drawn as a ball-top stick (`shape: .circle`,
   `paletteSlot: .stick`), six buttons in two staggered rows, `coin` and `start` up top.
   `coin` token is `"coin"`/`"insertcoin"`, already resolved for MAME/Neo Geo.
3. **Paddle family**: one `stick(.left, click: nil)` constrained to the x axis.
4. **DualDPad family** and the `landscapeOnly` binding flag, with `OverlayLayout` honouring
   it by resolving the landscape template in portrait and letting the screen planner use
   `centerColumn`.
5. **Hidden slots**: `SystemOverlayBinding.tokens` may omit an optional slot
   (`l`, `r`, `l2`, `r2`, `select`, `x`, `y`); `OverlayFamilyKit` already skips controls
   whose slot has no token. Make that behaviour explicit and tested, so "TwoButton with
   one button" needs no new family.
6. **Actions**: `.keypad`, `.flip`, `.diskSide`, `.service` added to `OverlayAction`,
   each routed through `OverlayInputSinkAdapter.handlerToken` to the handler tokens that
   already exist (`keyboard`, `mouse`, `flip`, `diskside`, `service`) or added there.

## 5. Handler token gaps

`DeltaSkinInputHandler` resolves `PV<System>Button(id)` for 45 systems. Missing or shared:

| System | Resolution |
|---|---|
| Atomiswave, NAOMI, NAOMI 2 | add to the Dreamcast branch (`PVDreamcastButton`) |
| CPS1/2/3, Neo Geo CD | add to the MAME / Neo Geo branches |
| Atari ST, C64, MSX/MSX2, ZX Spectrum, EP128, PC-98, Macintosh, PalmOS, TIC-80 | thin libretro cores: route through `PVThinLibretroCore`'s joypad token map (`RETRO_DEVICE_ID_JOYPAD_*`), which the handler already uses for libretro cores without a PV enum |
| FDS → NES, SGFX/PCE CD → PCE, NGPC → NGP, WS Color → WS, Jaguar CD → Jaguar, PS3 → PS2 | alias in the handler's system switch |

## 6. Screens

No new policies. `dualStacked3DS` was added for the 3DS. Aspect comes from the core
(`screenRect`/`aspectSize`) as today; Virtual Boy and PSP only need their cores to report
the right aspect, which they do.

## 7. Tests (`PVTouchOverlayTests`)

- `BindingCoverageTests`: every `SystemIdentifier` with a core either has a binding or is
  in the explicit `unsupported` list (RetroArch, Music). Fails when a system is added
  without a binding.
- `BindingResolvesTests`: for every binding × subtype × orientation, `OverlayFamilyKit`
  produces a template whose required slots all have tokens, and `OverlayScreenPlanner`
  returns the number of screens the policy promises.
- `KeypadFamilyTests`, `ArcadeStickFamilyTests`, `PaddleFamilyTests`, `DualDPadFamilyTests`:
  control counts, no overlaps at iPhone and iPad canvases, keypad toggle visibility.
- Snapshot tests of one template per family per orientation (Prefire, existing harness).

## 8. Delivery

Three batches, each a PR, each leaving develop shippable:

1. **Engine + arcade/Atari** (§4 items 1–6, bindings for the Keypad and ArcadeStick
   systems, palettes `atari`, `arcade`, `capcom`, `neoGeo`, `dreamcast`, `intellivision`,
   `coleco`). Biggest visible win: every arcade board and Atari stops using the purple pad.
2. **Sega, NEC, SNK handhelds, Sony** (Saturn, Dreamcast, PCE family, NGP, WonderSwan,
   PS2/PS3/PSP, CD-i, Vectrex, Odyssey², Virtual Boy).
3. **Computers and the rest** (DOS family, C64, MSX, ZX, PC-98, Mac, Palm, TIC-80,
   Lynx, Game Boy relatives, Master System relatives), then delete
   `DefaultControllerSkinView` and `DefaultDeltaSkin`'s per-system layouts on iOS.

Each batch: bindings + palettes + tests + a device smoke list added to
`docs/RELEASE_SMOKE_TESTS.md` (launch, press every button, screen placement in both
orientations, editor move/reset).

## 9. Out of scope

- Keyboard art for computers (the keyboard toggle stays).
- Light-gun, Wii pointer and trackpad surfaces beyond what Phase 1 routes today.
- tvOS: the overlay is touch-only; tvOS keeps the controller-only path.
- Per-game default variants (the editor's per-game store already covers it).
