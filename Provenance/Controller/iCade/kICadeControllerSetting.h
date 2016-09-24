//
//  kICadeControllerSetting.h
//  Provenance
//
//  Created by Josejulio Martínez on 10/07/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#ifndef Provenance_kICadeControllerSetting_h
#define Provenance_kICadeControllerSetting_h

#import "PViCadeController.h"

typedef NS_ENUM(NSUInteger, kICadeControllerSetting) {
    kICadeControllerSettingDisabled,
    kICadeControllerSettingStandard,
    kICadeControllerSetting8BitdoNES30,
    kICadeControllerSetting8BitdoSFC30,
    kICadeControllerSettingSteelSeries,
    kICadeControllerSetting_Count
};

NSString* kIcadeControllerSettingToString(kICadeControllerSetting value);

PViCadeController* kIcadeControllerSettingToPViCadeController(kICadeControllerSetting value);

#endif
