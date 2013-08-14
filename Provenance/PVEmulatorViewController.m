//
//  PVEmulatorViewController.m
//  Provenance
//
//  Created by James Addyman on 14/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVEmulatorViewController.h"
#import "PVGLViewController.h"
#import "PVGenesisEmulatorCore.h"
#import "OEGameAudio.h"

@interface PVEmulatorViewController ()

@property (nonatomic, strong) PVGenesisEmulatorCore *genesisCore;
@property (nonatomic, strong) PVGLViewController *glViewController;
@property (nonatomic, strong) OEGameAudio *gameAudio;

@end

@implementation PVEmulatorViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
		
	}
	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.genesisCore = [[PVGenesisEmulatorCore alloc] init];
	NSString *gamePath = [[NSBundle mainBundle] pathForResource:@"Sonic2" ofType:@"smd"];
	[self.genesisCore loadFileAtPath:gamePath];
	[NSTimer scheduledTimerWithTimeInterval:1/[self.genesisCore frameInterval]
									 target:self
								   selector:@selector(runEmulator:)
								   userInfo:nil
									repeats:YES];
	
	self.gameAudio = [[OEGameAudio alloc] initWithCore:self.genesisCore];
	[self.gameAudio setVolume:1.0];
	[self.gameAudio setOutputDeviceID:0];
	[self.gameAudio startAudio];
	
	self.glViewController = [[PVGLViewController alloc] init];
	[self.glViewController setFrameInterval:[self.genesisCore frameInterval]];
	[self.glViewController setBufferSize:[self.genesisCore bufferSize]];
	[self.glViewController setVideoBuffer:[self.genesisCore videoBuffer]];
	[[self.glViewController view] setFrame:CGRectMake([self.view bounds].size.width - 320, 0, 320, 224)];
	[[self.glViewController view] setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin];
	
	[self.view addSubview:[self.glViewController view]];
}

- (void)runEmulator:(NSTimer *)timer
{
	[self.genesisCore executeFrame];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
	{
		[UIView animateWithDuration:duration
							  delay:0.0
							options:UIViewAnimationOptionBeginFromCurrentState
						 animations:^{
							 [[self.glViewController view] setFrame:CGRectMake([self.view bounds].size.width - 320, 0, 320, 224)];
						 }
						 completion:^(BOOL finished) {
						 }];
	}
	else
	{
		[UIView animateWithDuration:duration
							  delay:0.0
							options:UIViewAnimationOptionBeginFromCurrentState
						 animations:^{
							 [[self.glViewController view] setFrame:CGRectMake(([self.view bounds].size.width - 472) / 2, 0, 457, 320)];
						 }
						 completion:^(BOOL finished) {
						 }];
	}
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
}

@end
