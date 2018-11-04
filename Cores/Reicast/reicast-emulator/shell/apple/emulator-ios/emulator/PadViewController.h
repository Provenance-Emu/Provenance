//
//  PadViewController.h
//  reicast-ios
//
//  Created by Lounge Katt on 8/25/15.
//  Copyright (c) 2015 reicast. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EmulatorView.h"

@interface PadViewController : UIViewController

@property (nonatomic, strong) IBOutlet UIButton* img_dpad_l;
@property (nonatomic, strong) IBOutlet UIButton* img_dpad_r;
@property (nonatomic, strong) IBOutlet UIButton* img_dpad_u;
@property (nonatomic, strong) IBOutlet UIButton* img_dpad_d;
@property (nonatomic, strong) IBOutlet UIButton* img_abxy_a;
@property (nonatomic, strong) IBOutlet UIButton* img_abxy_b;
@property (nonatomic, strong) IBOutlet UIButton* img_abxy_x;
@property (nonatomic, strong) IBOutlet UIButton* img_abxy_y;
@property (nonatomic, strong) IBOutlet UIButton* img_vjoy;
@property (nonatomic, strong) IBOutlet UIButton* img_lt;
@property (nonatomic, strong) IBOutlet UIButton* img_rt;
@property (nonatomic, strong) IBOutlet UIButton* img_start;

@property (nonatomic, strong) EmulatorView *handler;

- (void) showController:(UIView *)parentView;
- (void) hideController;
- (BOOL) isControllerVisible;
- (void) setControlOutput:(EmulatorView *)output;

@end
