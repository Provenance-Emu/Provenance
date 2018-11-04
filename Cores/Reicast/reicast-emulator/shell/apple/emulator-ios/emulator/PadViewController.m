//
//  PadViewController.m
//  reicast-ios
//
//  Created by Lounge Katt on 8/25/15.
//  Copyright (c) 2015 reicast. All rights reserved.
//

#import "PadViewController.h"
#import "EmulatorView.h"

@interface PadViewController ()

@end

@implementation PadViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)showController:(UIView *)parentView
{
	self.view.hidden = NO;
}

- (void)hideController
{
	self.view.hidden = YES;
}

- (BOOL)isControllerVisible {
	if (self.view.window != nil) {
		return YES;
	}
	return NO;
}

- (void)setControlOutput:(EmulatorView *)output
{
	self.handler = output;
}

- (IBAction)keycodeDown:(id)sender
{
	[self.handler handleKeyDown:(UIButton*)sender];
}

- (IBAction)keycodeUp:(id)sender
{
	[self.handler handleKeyUp:(UIButton*)sender];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self) {
		// Custom initialization
	}
	return self;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
