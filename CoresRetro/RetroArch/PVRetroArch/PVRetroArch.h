//
//  PVRetroArch.h
//  PVRetroArch
//
//  Created by Mattiello, Joseph R on 12/19/16.
//
//
#import <Foundation/Foundation.h>

//! Project version number for PVRetroArch.
FOUNDATION_EXPORT double PVRetroArchVersionNumber;

//! Project version string for PVRetroArch.
FOUNDATION_EXPORT const unsigned char PVRetroArchVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <PVRetroArch/PublicHeader.h>
#import <PVRetroArch/PVRetroArchCoreBridge.h>
//#import <PVRetroArch/PVRetroArchCoreBridge+Audio.h>
//#import <PVRetroArch/PVRetroArchCoreBridge+Controls.h>
//#import <PVRetroArch/PVRetroArchCoreBridge+Video.h>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
#pragma clang diagnostic ignored "-Wnone"
#pragma clang diagnostic ignored "-Wmodule-import-in-extern-c"
#import <PVRetroArch/autosave.h>
#import <PVRetroArch/audio_driver.h>
#import <PVRetroArch/cheat_manager.h>
#import <PVRetroArch/command.h>
#import <PVRetroArch/configuration.h>
#import <PVRetroArch/content.h>
#import <PVRetroArch/core.h>
#import <PVRetroArch/core_info.h>
#import <PVRetroArch/core_option_manager.h>
#import <PVRetroArch/core_updater_list.h>
#import <PVRetroArch/defaults.h>
#import <PVRetroArch/disk_control_interface.h>
#import <PVRetroArch/disk_index_file.h>
#import <PVRetroArch/dynamic.h>
#import <PVRetroArch/libretro.h>
#import <PVRetroArch/retroarch.h>
#import <PVRetroArch/runloop.h>
#pragma clang diagnostic pop

//#import <PVRetroArch/PVRetroArchCoreBridge+Audio.h>
//#import <PVRetroArch/PVRetroArchCoreBridge+Controls.h>
//#import <PVRetroArch/PVRetroArchCoreBridge+Saves.h>
//#import <PVRetroArch/PVRetroArchCoreBridge+Video.h>
