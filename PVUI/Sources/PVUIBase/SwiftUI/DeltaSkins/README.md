# DeltaSkins

Provenance's controller skins follow the DeltaSkins specification from [Delta-Docs](https://github.com/noah978/Delta-Docs/blob/master/skins/README.md).

The skin code itself lives in [SkinKit](https://github.com/Provenance-Emu/SkinKit), which iFly and iCube share:

| SkinKit product | What it holds |
|---|---|
| `SkinKitCore` | `info.json` model, decoding, trait and layout resolution |
| `SkinCatalogKit` | Skin catalog models, catalog service, store sections |
| `SkinKitManager` | Import, scan, storage, per-game and per-system skin selection |
| `SkinKitUI` | Skin rendering, `DeltaSkinView`, skin pickers, catalog store views |

Change skin behavior in SkinKit, then bump the revision in `PVUI/Package.swift`, `PVTouchOverlay/Package.swift` and `Provenance.xcworkspace`'s `Package.resolved`.

## What stays in Provenance

This folder keeps the code that touches emulator internals or app-only types:

- `SkinKitSetup.swift`: wires SkinKit's hooks (storage location, case-controller skins, settings, systems, theme, catalog seed). Every app calls `SkinKitSetup.configure()` at launch, before anything touches a skin.
- `Models/DeltaSkinInputHandler.swift`: forwards skin input to the emulator core. It conforms to SkinKitUI's `DeltaSkinInputHandling`.
- `SystemIdentifier` mappings (`DeltaSkinGameType+SystemIdentifier`, `SystemIdentifier+SkinCatalog`, the `+SystemIdentifier` overloads of the manager and selection queries).
- Emulator views: `Views/Display/`, `Views/Components/` (container, light gun, hardware switches, viewport bridge), `Views/Deprecated/`.
- `CaseControllerSkinCoordinator`, `DeltaSkinDefaults`, the GameCube / Wii token tables, the skin preview cache (`PVMediaCache`), and the AI enhancer.

## Usage

```swift
DeltaSkinView(
    skin: skin,                      // any DeltaSkinRenderable
    traits: DeltaSkinTraits(device: .iphone, displayType: .standard, orientation: .portrait),
    inputHandler: inputHandler,      // any DeltaSkinInputHandling
    onViewportFrameChange: { frame in core.viewportLayoutDelegate?.viewportFrameDidUpdate(frame) }
)
.deltaSkinInputHandler(inputHandler)  // for DeltaSkinScreensView inside it
```

Pickers take SkinKit values built from Provenance's types: `SystemSkinSelectionView(system: systemIdentifier.deltaSkinSystem, game: game.deltaSkinGameContext)`.

Enable the debug overlay with `.environment(\.debugSkinMappings, true)`.
