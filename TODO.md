# TODO.md

## Before merge to release

- [ ] Remove or fix spotlight breaking the library
- [ ] Better screenshot support (protocol, fix gamecube and retroarch)
- [X] Dolhin hacks options, especially vbi sync off
- [ ] Fix all @MainActor code in cloudkit sync
- [ ] Fix rotation
- [ ] Option to use a custom skin or not
- [ ] if rotate and same skin, don't reload
- [ ] Retroarch needs to pause showing menu
- [X] remove slow metalvc logs
- [ ] singlepage error on loading core results in stuck screen
- [ ] some cores, like quake not showing retroarch controller even though it should be on for them
- [ ] RetroArch save states isn't accurate

## Skins

- [X] save and quit in the new pause menu
- [X] uikit settings needs useUIKit replaced with new selections
- [X] homeview settings bar size and padding
- [ ] RetroArch cores don't work with skins
- [ ] fix deltaskin showing up on rotate when off
- [ ] fix deltaskin joysticks

## Other

- [ ] Move unsupport cores to general settings?
- [ ] Moveable buttons goes weird
- [ ] Moveable buttons in the pause menu and close button
- [ ] Indicator in import queue for roms that are being copied from the cloud
- [ ] Indicator on game start that could games are being downloaded
- [ ] Add mutli-select delete/move/favorite support
- [ ] Hookup PVMediaCache trimDiskCache, fix it, and make it work with the status info thing (maybe add a force button too)
- [ ] retroarch audio visualizer
- [ ] test v-sync
- [ ] RETRO_ENVIRONMENT_SET_PROC_ADDRESS_CALLBACK for Melon DS specific screen layout, reference JesseTG message in Discord for details, https://github.com/libretro/RetroArch/blob/master/libretro-common/include/libretro.h#L1366-L1387
