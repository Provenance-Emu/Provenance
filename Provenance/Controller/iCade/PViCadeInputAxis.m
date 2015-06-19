//
//  PViCadeInputAxis.m
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "PViCadeInputAxis.h"

@implementation PViCadeAxisInput

-(void) setValue:(float) value {
    _value = value;
}

-(float) value {
    return _value;
}

@end