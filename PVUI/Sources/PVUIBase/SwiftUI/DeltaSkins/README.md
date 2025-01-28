# DeltaSkins Implementation

This folder contains the implementation of the DeltaSkins specification from [Delta-Docs](https://github.com/noah978/Delta-Docs/blob/master/skins/README.md).

## Key Features

- Full support for both PDF and PNG assets
- Screen groups for multi-screen systems (DS)
- Button mapping with directional inputs
- Debug overlay for skin development
- Asset size validation
- Screen and button configuration validation
- Support for all iOS devices and orientations

## Components

- `Models/` - Core data structures and parsing
- `Views/` - SwiftUI views for displaying skins
- `Protocols/` - Interface definitions
- `Resources/` - Test skins and assets

## Usage

### Displaying a Skin

To display a skin in your view:

```
DeltaSkinScreensView(
    skin: skin,
    traits: DeltaSkinTraits(
        device: .iphone,
        displayType: .standard,
        orientation: .portrait
    ),
    containerSize: view.bounds.size
)
```

### Listing Available Skins

To show a grid of available skins:

```
DeltaSkinListView(
    traits: DeltaSkinTraits(
        device: .iphone,
        displayType: .standard,
        orientation: .portrait
    ),
    gameType: "com.rileytestut.delta.game.gbc"
)
```

### Debug Mode

Enable debug mode to show button mappings and screen frames:

```
DeltaSkinScreensView(skin: skin, traits: traits, containerSize: size)
    .environment(\.debugSkinMappings, true)
```


## Testing

The UITesting app provides two main testing interfaces:

1. DeltaSkinTestView
   - Test individual skins
   - Try different device configurations
   - Validate skin layouts
   - Debug button mappings
   - View screen configurations

2. DeltaSkinListView
   - Browse all available skins
   - Filter by game type
   - Test different device configurations
   - Preview skins in a grid layout

## Validation

The implementation includes validation for:
- Asset sizes for different devices
- Screen configurations
- Button mappings
- Input configurations
- Extended edges
- Game screen frames

## Advanced Features

When `FeatureFlag.advancedSkinFeatures` is enabled:
- CoreImage filters for screens
- Debug overlays
- Screen group translucency
- Extended touch areas

## Supported Systems

- Game Boy Color (GBC)
- Game Boy Advance (GBA)
- Nintendo DS (NDS)
- Super Nintendo (SNES)
- Sega Genesis
- Nintendo 64 (N64)

Each system has specific screen configurations and default sizes handled by the implementation.
