//
//  PVButtonOverlayView.h
//  Provenance
//
//  Created by James Addyman on 17/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>

@class JSButton;
@interface PVButtonGroupOverlayView : UIView

- (instancetype _Nonnull)initWithButtons:(NSArray<JSButton*> * _Nonnull)buttons;

@end
