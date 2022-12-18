//
//  PVApp.h
//  PVApp
//
//  Created by Joseph Mattiello on 12/18/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for PVApp.
FOUNDATION_EXPORT double PVAppVersionNumber;

//! Project version string for PVApp.
FOUNDATION_EXPORT const unsigned char PVAppVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <PVApp/PublicHeader.h>

#import <PVApp/PVGLViewController.h>
#import <PVApp/PVMetalViewController.h>
#import <PVApp/PVWebServer.h>

#if !TARGET_OS_TV && !TARGET_OS_OSX && !TARGET_OS_MACCATALYST
    #import <PVApp/PVAltKitService.h>
#endif

#if TARGET_OS_IOS || TARGET_OS_TV
    #import <PVApp/UIDevice+Hardware.h>
    #import <PVApp/MBProgressHUD.h>
    #import <PVApp/PVLogViewController.h>
#endif
