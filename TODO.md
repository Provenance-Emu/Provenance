# TODO.md

## tvOS

- [ ] New banner image that doesn't use copyrighted art
- [X] TopShelf extension working and right archs
- [X] Contenxt Menu 'Games'
  - [X] Remove skins item
  - [X] Rename and other alerts needt to steal focus
- [X] Add a way to open the import queue
- [X] RetroArch cores not centered
- [X] Settings UI
  - [X] Back on sub-pages opens side menu
  - [X] Sub-pages with left scrolling selection always opens menu
- [X] Pause menu
  - [X] Pause menu 'Game Info' UI broken
  - [X] Opening Core Options unpauses the game
  - [X] Screen filter selector not working
  - [X] Cheat Codes UI crashes
  - [X] mFI double tap home hides app instead of showing pause menu
- [ ] RetroArch cores MFi issue
    - [ ] Controller 1 presses both p1 and p2
    - [ ] Controller 1 share shows retroarch menu, should be pause?
    - [ ] Controller 1 options (start) presses P2 start only (doesn't seem to be siri remote)
- [ ] Space is blowing up?
- [X] CloudKit PVGame "Favorite" and other values possibly not syncing
- [X] Log viewer UI, can't scroll on tvOS, can only access from settings, and focus could be pretteir
- [X] 3.3.0 release notes to app

## Before merge to release

- [ ] some cores, like quake not showing retroarch controller even though it should be on for them

## Other

- [ ] Move unsupport cores to general settings?
- [ ] Moveable buttons goes weird
- [ ] Moveable buttons in the pause menu and close button
- [X] Indicator in import queue for roms that are being copied from the cloud
- [X] Indicator on game start that cloud games are being downloaded
- [ ] Add mutli-select delete/move/favorite support
- [ ] Hookup PVMediaCache trimDiskCache, fix it, and make it work with the status info thing (maybe add a force button too)
- [X] retroarch audio visualizer
- [X] test v-sync
- [ ] RETRO_ENVIRONMENT_SET_PROC_ADDRESS_CALLBACK for Melon DS specific screen layout, reference JesseTG message in Discord for details, https://github.com/libretro/RetroArch/blob/master/libretro-common/include/libretro.h#L1366-L1387
