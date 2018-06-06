//
//  kICadeControllerSetting.h
//  Provenance
//
//  Created by Josejulio Martínez on 10/07/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#import "PViCadeController.h"

typedef NS_ENUM(NSInteger, iCadeControllerSetting) {
    iCadeControllerSettingDisabled,
    iCadeControllerSettingStandard,
    iCadeControllerSetting8Bitdo,
    iCadeControllerSettingSteelSeries,
    iCadeControllerSetting8BitdoZero,
	iCadeControllerSettingMocute,
    iCadeControllerSettingCount
};

NSString*_Nullable iCadeControllerSettingToString(iCadeControllerSetting value);

PViCadeController*_Nullable iCadeControllerSettingToPViCadeController(iCadeControllerSetting value);
