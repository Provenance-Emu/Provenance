//
//  CoresRetro.h
//  CoresRetro
//
//  Created by Joseph Mattiello on 7/8/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for CoresRetro.
FOUNDATION_EXPORT double CoresRetroVersionNumber;

//! Project version string for CoresRetro.
FOUNDATION_EXPORT const unsigned char CoresRetroVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <CoresRetro/PublicHeader.h>
#import <PVblueMSX/PVblueMSX.h>
#import <PVDesmume2015/PVDesmume2015.h>
#import <PVDosBox/PVDosBox.h>
#import <PVEP128Emu/PVEP128Emu.h>
#import <PVGME/PVGME.h>
#import <PVMelonDS/PVMelonDS.h>
#import <PVMiniVMac/PVMiniVMac.h>
#import <PVOpera/PVOpera.h>
#import <PVPotator/PVPotator.h>
#import <PVVecX/PVVecX.h>
#if BROKEN_CORES
#import <PVBeetlePSX/PVBeetlePSX.h>
#import <PVblueMSX/PVblueMSX.h>
#import <PVCitra/PVCitra.h>
#import <PVFBNeo/PVFBNeo.h>
#import <PVFlycast/PVFlycast.h>
#import <PVfMSX/PVfMSX.h>
#import <PVFreeIntv/PVFreeIntv.h>
#import <PVFuse/PVFuse.h>
#import <PVGearcoleco/PVGearcoleco.h>
#import <PVHatari/PVHatari.h>
#import <PVMu/PVMu.h>
#import <PVMupen64Plus-NX/PVMupen64Plus-NX.h>
#import <PVPCSXRearmed/PVPCSXRearmed.h>
#import <PVSameDuck/PVSameDuck.h>
#import <PVTIC80/PVTIC80.h>
#import <PVYabause/PVYabause.h>
#endif
