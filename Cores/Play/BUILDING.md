# BUILDING.md

How to build and update the build for the Play! core.

## Updating CMAKE

Installation Steps

1. run `cmake/update.sh`
2. Append 'Play' to module names eg; `AltKit` => `AltKitPlay`
3. change build directory to `$SRCROOT/lib/play/$(CONFIGURATION)` the project level.
4. Change project level settings `ARCHS = $(ARCHS_STANDARD)`, `SDKROOT = auto`
    4.1 Delete `SDKROOT` and `ARCHS` from library targets. Tip, select all targets and delete the settings in one
5. Erase `Loader.cpp` from `Framework_Vulkan` static lib target, replace with `Loader.cpp` in `PVPlayCore/Core/Loader.cpp`
6. Run `python3 xcode_absolute_path_to_relative.py`  
7. Erase `CMakefiles` / `.cmake` / `.make` files
8. Add` Loader.cpp` / and other files in `PVPlayCore/Play` to appropriate project (PlayCore)

## Oragnization

### `PVPlayCore.xcodeproj`

### `cmake/Play.xcodeproj`
