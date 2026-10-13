# Slang shader library

Provenance bundles two sets of shader presets.

## libretro slang shaders

The libretro `slang-shaders` collection (https://github.com/libretro/slang-shaders),
compiled to Metal Shading Language by the OpenEmu-Shaders `oeshaders` tool and
published at https://github.com/JoeMatt/slang-shaders-metal. The release used is
pinned in `Scripts/shaders/slang-shaders.lock.json`.

Each shader keeps the license of its upstream source. The collection mixes
public-domain, MIT, BSD and GPL-licensed shaders; see the upstream repository
for the license of an individual shader.

## Provenance native-metal presets

Hand-written Metal presets under `PVShaders/Library/native-metal/`, by
Joseph Mattiello, distributed under Provenance's license.

## Runtime

The multi-pass runtime in `PVShaders/Sources/PVSlangRuntime` is derived from
OpenEmu-Shaders (Copyright (c) 2019-2022, OpenEmu Team), BSD 3-Clause; the
license text is kept in each source file's header.
