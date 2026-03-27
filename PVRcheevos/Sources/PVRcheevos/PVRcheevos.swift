//
//  PVRcheevos.swift
//  PVRcheevos
//
//  Public entry point for the PVRcheevos Swift module.
//
//  ## Usage
//
//  Swift targets should depend on `PVRcheevos` and `import PVRcheevos`.
//  Objective-C / C++ targets can depend directly on `CRcheevos` and
//  `#include <rc_client.h>`.
//
//  ## Authentication flow
//
//  1. Call `rc_client_begin_login_with_token` once per session (at app launch
//     or after the user logs in via Settings).
//  2. After each ROM load, call `rc_client_begin_load_game` with the ROM MD5.
//  3. After each emulated frame, call `rc_client_do_frame`.
//  4. Register an event handler (`rc_client_set_event_handler`) to receive
//     unlock / progress / challenge / leaderboard notifications.
//

//  ## Pure-Swift utilities
//
//  `RcheevosByteSwapMode`, `RcheevosAddressSpace`, and `RcheevosMemoryRegion`
//  are re-exported from `PVRcheevosCore` (no C dependency, testable on Linux).
//  Tests live in PVRcheevosCore/: `cd PVRcheevosCore && swift test`
//

@_exported import CRcheevos
@_exported import PVRcheevosCore
