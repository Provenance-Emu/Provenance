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
#import "PViCadeMocuteController.h"

NSString* iCadeControllerSettingToString(iCadeControllerSetting value) {
    NSString* stringRepresentation = nil;
    switch (value) {
        case iCadeControllerSettingDisabled:
            stringRepresentation = @"Disabled";
            break;
        case iCadeControllerSettingStandard:
            stringRepresentation = @"Standard Controller";
            break;
        case iCadeControllerSetting8Bitdo:
            stringRepresentation = @"8Bitdo Controller";
            break;
        case iCadeControllerSetting8BitdoZero:
            stringRepresentation =  @"8Bitdo Zero Controller";
            break;
		case iCadeControllerSettingSteelSeries:
			stringRepresentation = @"SteelSeries Free Controller";
			break;
		case iCadeControllerSettingMocute:
			stringRepresentation = @"Mocute Controller";
			break;
		default:
            break;
    }
    
    return stringRepresentation;
}

PViCadeController* iCadeControllerSettingToPViCadeController(iCadeControllerSetting value) {
    PViCadeController* controller = nil;
    switch (value) {
        case iCadeControllerSettingDisabled:
            controller = nil;
            break;
        case iCadeControllerSettingStandard:
            controller = [[PViCadeController alloc] init];
            break;
        case iCadeControllerSetting8Bitdo:
            controller = [[PViCade8BitdoController alloc] init];
            break;
		case iCadeControllerSetting8BitdoZero:
			controller = [[PViCade8BitdoZeroController alloc] init];
			break;
        case iCadeControllerSettingSteelSeries:
            controller = [[PViCadeSteelSeriesController alloc] init];
            break;
		case iCadeControllerSettingMocute:
			controller = [[PViCadeMocuteController alloc] init];
			break;
        default:
            break;
    }
    return controller;
}
