//
//  PVMupen64PlusCoreMain.c
//  PVMupen64Plus
//
//  SwiftPM infers an *executable* target from a source file named main.c, so the core's
//  main/main.c (g_dev, main_run, open_pif, new_frame, ...) is compiled through this
//  wrapper instead of being listed by its own name. Nothing else about it changes: the
//  frontend hooks it calls (new_vi, event_*, TakeScreenshot, VidExt_*) are defined by
//  PVMupenBridge (new_vi_main.m, eventloop.m, screenshot.m, vidext.m), exactly as in the
//  xcodeproj, where main.c is compiled inside the bridge framework.
//

#include "Core/src/main/main.c"
