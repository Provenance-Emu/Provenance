//
//  PViCade8BitdoController.h
//  Provenance
//
//  Created by Josejulio Martínez on 10/07/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PViCadeController.h"

typedef NS_ENUM(NSUInteger, ICade8bitdoControllerType) {
    ICade8bitdoControllerTypeNES30,
    ICade8bitdoControllerTypeSFC30,
};

@interface PViCade8BitdoController : PViCadeController

-(instancetype) initWithControllerType:(ICade8bitdoControllerType)controllerType;

@end
