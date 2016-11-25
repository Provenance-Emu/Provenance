//
//  kICadeControllerSetting.c
//  Provenance
//
//  Created by Josejulio Martínez on 10/07/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#include "kICadeControllerSetting.h"
#import "PViCade8BitdoController.h"
#import "PViCadeSteelSeriesController.h"


NSString* kIcadeControllerSettingToString(kICadeControllerSetting value) {
    NSString* stringRepresentation = nil;
    switch (value) {
        case kICadeControllerSettingDisabled:
            stringRepresentation = @"Disabled";
            break;
        case kICadeControllerSettingStandard:
            stringRepresentation = @"Standard Controller";
            break;
        case kICadeControllerSetting8Bitdo:
            stringRepresentation = @"8Bitdo Controller";
            break;
        case kICadeControllerSettingSteelSeries:
            stringRepresentation = @"SteelSeries Free Controller";
        default:
            break;
    }
    
    return stringRepresentation;
}

PViCadeController* kIcadeControllerSettingToPViCadeController(kICadeControllerSetting value) {
    PViCadeController* controller = nil;
    switch (value) {
        case kICadeControllerSettingDisabled:
            controller = nil;
            break;
        case kICadeControllerSettingStandard:
            controller = [[PViCadeController alloc] init];
            break;
        case kICadeControllerSetting8Bitdo:
            controller = [[PViCade8BitdoController alloc] init];
            break;
        case kICadeControllerSettingSteelSeries:
            controller = [[PViCadeSteelSeriesController alloc] init];
            break;
        default:
            break;
    }
    return controller;
}
