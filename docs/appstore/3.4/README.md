# Provenance 3.4 App Store assets

Screenshots and listing copy for the 3.4 launch, made 2026-10-15. Draft for owner review: nothing
here has been uploaded to App Store Connect.

| Folder | Device class | Size (px) | Shots |
|---|---|---|---|
| `screenshots/iphone/` | iPhone 6.9" | 1320 × 2868 | 8 |
| `screenshots/ipad/` | iPad 13" | 2064 × 2752 | 7 |
| `screenshots/appletv/` | Apple TV | 1920 × 1080 | 5 |
| `metadata.md` | Name, subtitle, promotional text, keywords, description, What's New (iOS and tvOS) | | |

Every PNG is flattened RGB with no alpha, at the exact size for its slot. Filenames sort in store order.
Smaller iPhone and iPad classes scale from these sizes, so none are needed.

## What is on screen

- **Real app screens.** Every frame comes from the Provenance-Dev-UI focused app (develop at
  98ce866151, with another session's uncommitted library-sharing edits in the tree) running on iOS 26.5 / tvOS 26.5 simulators.
- **Library.** The games are fictional. Their ROM files are random bytes, and their covers come from
  `tools/make_covers.py` (geometry plus OFL fonts).
- **Gameplay.** Real mGBA emulation of three original "demo cartridges" built by
  `tools/make_demo_roms.py`. Each one is a pixel-art scene drawn in code and shown by a few ARM
  instructions.
- **No third-party content.** No commercial ROM, box art, title or logo appears anywhere, so App Store
  Connect's "does not use third-party content" answer stays true for the screenshots.
- **One edit to the captures.** `tools/clean_raws.py` paints out the `#if DEBUG` ladybug button that
  Debug builds draw in the corner of emulator screens. Release builds never show it, and nothing else
  in the frames is altered.
- **Template.** The retrowave frame (gradient sky, striped sun, grid floor, PVThemes RetroWave palette,
  benefit-led captions) is built in `tools/compose.py`. The iFly Figma template link wasn't available,
  so this follows the same structure: caption on top, device below, one background across the set.
  Swap in the Figma version later by replacing the frame and keeping the raw captures.

## Regenerate

```bash
cd docs/appstore/3.4/tools
python3 make_demo_roms.py OUT/roms      # demo cartridges (+ preview PNGs)
python3 make_covers.py OUT/covers       # cover art, <rom file>.png
# Library setup: copy the ROMs (named after the covers) into the app's Imports folder and relaunch;
# then copy the covers in as "<rom file>.png". tvOS imports from Library/Caches/Imports.
# Capture raw screens with `xcrun simctl io <udid> screenshot` into RAW/{iphone,ipad,tv}/.
python3 clean_raws.py RAW
python3 compose.py shots.json RAW OUT   # framed PNGs at App Store sizes
python3 check_metadata.py               # field lengths in metadata.md
```

Requires Pillow. The raw captures are not committed; they live only in the capture session.

## Needs a real device or owner review

**Screens the simulator could not produce**
- **iCloud sync screen.** The simulator has no iCloud account, so every Cloud Sync page shows a red
  "No iCloud account" banner. iCloud appears only in captions (iPhone 07, iPad 07, Apple TV 05). A
  device capture of Settings › Library › Cloud Sync with sync on would make a stronger shot.
- **RetroAchievements screen.** It needs a signed-in account; the simulator shows "Not logged in". It
  is not pictured. A device capture with the owner's account, and an achievement toast in-game, would
  add a shot.
- **Apple TV pause menu, settings and CRT filter.** The tvOS simulator could only be driven by
  accessibility presses, with no remote Menu button, so the pause menu and the settings sidebar are
  missing from the Apple TV set.
  - A per-game or global Mega Tron selection did not render on the tvOS simulator, though the same
    selection draws on iOS. That needs a device check, both as a screenshot and as a possible
    tvOS filter bug.
  - Capture the Apple TV pause menu, Settings and a CRT frame on a real Apple TV, or drive the
    simulator from its remote panel.
- **iPad landscape.** The iPad set is portrait (2064 × 2752). The settings sidebar was captured in
  Single Page UI mode, where Settings fills the screen. In the default Paged mode, Settings is a form
  sheet narrower than the sidebar's 600 pt minimum, so it shows the tab strip on iPad portrait.
  Consider whether Paged mode should present Settings wider on iPad.

**Content and claims to approve**
- **Captions to confirm:**
  - "Over 1,000 looks": the filter browser lists 1,193.
  - "iCloud sync across iPhone, iPad and Apple TV": a Provenance Plus feature; it may need a "Plus" note.
  - "MFi, Xbox, PlayStation and Switch Online controllers": controller brand names in a screenshot.
- **Provenance Plus banner.** The Dev build shows "Provenance Plus Active" on the General settings
  pane. None of the chosen shots show that pane, but the side menu also says "Provenance Lite Plus",
  so keep the side menu out of any new captures.
- **Metadata claims.** See the table at the end of `metadata.md`: Edit Layout, Gameplay Clips (Plus?),
  RetroAchievements on the thin wrapper, NFC, ROM patching, DS/PSP in the system list, the 1.2 million
  cheat figure, and the keyword change away from console brand names.
- **Old screenshot set.** The September 2026 set in `fastlane/screenshots` (from the UITesting mock
  library) shows trademarked titles such as Super Mario World, Zelda and Pokémon. Don't upload it.
  Replace it with this set.
- **Storage.** `fastlane/screenshots/README.md` keeps store PNGs out of git and in the media release
  store (`Scripts/release/media-assets.sh`). This set (about 19 MB) is committed here because the task
  asked for it. To ship it through `deliver`, copy it into `fastlane/screenshots/{en-US,appleTV/en-US}/`
  and run `media-assets.sh upload`.

## Bugs noticed while capturing (not fixed here)

- **Import queue.** On a fresh install, files dropped into `Imports` while the app runs are not picked
  up until a relaunch. The import queue then stalls in WAITING with 0 processed, and already-imported
  ROMs reappear in the queue as "73 systems". Each relaunch imports a batch. It happened on iPhone,
  iPad and Apple TV simulators.
- **"Requires Sideload / JIT" on GBC.** The import queue labels a Game Boy Color ROM (mGBA)
  "Requires Sideload / JIT".
- **First `provenance://open?md5=` link.** It waits about 15 s before the game opens.
- **Lite name in the Dev build.** The side menu header reads "Provenance Lite Plus".
