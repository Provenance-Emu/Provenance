//
//  PVTGBDualCore.h
//  PVTGBDual
//
//  Created by error404-na on 12/31/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVSupport/PVSupport-Swift.h>

#define TGBDUAL_PITCH_SHIFT  1
#define NUMBER_OF_PADS       2
#define NUMBER_OF_PAD_INPUTS 16

PVCORE
@interface PVTGBDualCore : PVEmulatorCore <PVGBSystemResponderClient> {
  
  uint16_t _gb_pad[NUMBER_OF_PADS][NUMBER_OF_PAD_INPUTS];
  uint16_t *_videoBuffer;
}

@property (nonatomic, assign) int videoWidth;
@property (nonatomic, assign) int videoHeight;

@end
