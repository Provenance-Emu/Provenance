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
#import "JSButton.h"
#import "JSDPad.h"

@interface PVEmulatorViewController ()

@property (nonatomic, strong) PVGenesisEmulatorCore *genesisCore;
@property (nonatomic, strong) PVGLViewController *glViewController;
@property (nonatomic, strong) OEGameAudio *gameAudio;
@property (nonatomic, strong) NSString *romPath;

@property (nonatomic, strong) JSDPad *dPad;
@property (nonatomic, strong) JSButton *aButton;
@property (nonatomic, strong) JSButton *bButton;
@property (nonatomic, strong) JSButton *cButton;
@property (nonatomic, strong) JSButton *startButton;

@end

@implementation PVEmulatorViewController

- (instancetype)initWithROMPath:(NSString *)path
{
	if ((self = [super init]))
	{
		self.romPath = path;
	}
	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.title = [self.romPath lastPathComponent];
	
	self.genesisCore = [[PVGenesisEmulatorCore alloc] init];
	
	[self.genesisCore loadFileAtPath:self.romPath];
	
	self.gameAudio = [[OEGameAudio alloc] initWithCore:self.genesisCore];
	[self.gameAudio setVolume:1.0];
	[self.gameAudio setOutputDeviceID:0];
	[self.gameAudio startAudio];
	
	self.glViewController = [[PVGLViewController alloc] initWithGenesisCore:self.genesisCore];
	[[self.glViewController view] setFrame:CGRectMake([self.view bounds].size.width - 320, 0, 320, 224)];
	[[self.glViewController view] setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin];
	
	[self.view addSubview:[self.glViewController view]];
	
	self.dPad = [[JSDPad alloc] initWithFrame:CGRectMake(10, [[self view] bounds].size.height - 160, 150, 150)];
	[self.dPad setAutoresizingMask:UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin];
	[self.dPad setDelegate:self];
	[self.dPad setAlpha:0.3];
	[self.view addSubview:self.dPad];
	
	self.aButton = [[JSButton alloc] initWithFrame:CGRectMake([[self view] bounds].size.width - 90, [[self view] bounds].size.height - 90, 80, 80)];
	[self.aButton setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin];
	[[self.aButton titleLabel] setText:@"A"];
	[self.aButton setBackgroundImage:[UIImage imageNamed:@"button"]];
	[self.aButton setBackgroundImagePressed:[UIImage imageNamed:@"button-pressed"]];
	[self.aButton setDelegate:self];
	[self.aButton setAlpha:0.3];
	[self.view addSubview:self.aButton];
	
	self.startButton = [[JSButton alloc] initWithFrame:CGRectMake(([[self view] bounds].size.width - 62) / 2, [self.view bounds].size.height - 32, 62, 22)];
	[self.startButton setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin];
	[self.startButton setBackgroundImage:[UIImage imageNamed:@"button-thin"]];
	[self.startButton setBackgroundImagePressed:[UIImage imageNamed:@"button-thin-pressed"]];
	[[self.startButton titleLabel] setText:@"Start"];
	[[self.startButton titleLabel] setFont:[UIFont boldSystemFontOfSize:12]];
	[self.startButton setTitleEdgeInsets:UIEdgeInsetsMake(0, 0, 4, 0)];
	[self.startButton setDelegate:self];
	[self.startButton setAlpha:0.3];
	[self.view addSubview:self.startButton];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	[self.genesisCore startEmulation];
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

#pragma mark - JSDPadDelegate

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
	[self.genesisCore releaseGenesisButton:PVGenesisButtonUp];
	[self.genesisCore releaseGenesisButton:PVGenesisButtonDown];
	[self.genesisCore releaseGenesisButton:PVGenesisButtonLeft];
	[self.genesisCore releaseGenesisButton:PVGenesisButtonRight];
	
	switch (direction)
	{
		case JSDPadDirectionUpLeft:
			[self.genesisCore pushGenesisButton:PVGenesisButtonUp];
			[self.genesisCore pushGenesisButton:PVGenesisButtonLeft];
			break;
		case JSDPadDirectionUp:
			[self.genesisCore pushGenesisButton:PVGenesisButtonUp];
			break;
		case JSDPadDirectionUpRight:
			[self.genesisCore pushGenesisButton:PVGenesisButtonUp];
			[self.genesisCore pushGenesisButton:PVGenesisButtonRight];
			break;
		case JSDPadDirectionLeft:
			[self.genesisCore pushGenesisButton:PVGenesisButtonLeft];
			break;
		case JSDPadDirectionRight:
			[self.genesisCore pushGenesisButton:PVGenesisButtonRight];
			break;
		case JSDPadDirectionDownLeft:
			[self.genesisCore pushGenesisButton:PVGenesisButtonDown];
			[self.genesisCore pushGenesisButton:PVGenesisButtonLeft];
			break;
		case JSDPadDirectionDown:
			[self.genesisCore pushGenesisButton:PVGenesisButtonDown];
			break;
		case JSDPadDirectionDownRight:
			[self.genesisCore pushGenesisButton:PVGenesisButtonDown];
			[self.genesisCore pushGenesisButton:PVGenesisButtonRight];
			break;
			
		default:
			break;
	}
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
	[self.genesisCore releaseGenesisButton:PVGenesisButtonUp];
	[self.genesisCore releaseGenesisButton:PVGenesisButtonDown];
	[self.genesisCore releaseGenesisButton:PVGenesisButtonLeft];
	[self.genesisCore releaseGenesisButton:PVGenesisButtonRight];
}

- (void)buttonPressed:(JSButton *)button
{
	if ([button isEqual:self.startButton])
	{
		[self.genesisCore pushGenesisButton:PVGenesisButtonStart];
	}
	else if ([button isEqual:self.aButton])
	{
		[self.genesisCore pushGenesisButton:PVGenesisButtonA];
	}
}

- (void)buttonReleased:(JSButton *)button
{
	if ([button isEqual:self.startButton])
	{
		[self.genesisCore releaseGenesisButton:PVGenesisButtonStart];
	}
	else if ([button isEqual:self.aButton])
	{
		[self.genesisCore releaseGenesisButton:PVGenesisButtonA];
	}
}

@end
