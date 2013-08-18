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
#import "UIActionSheet+BlockAdditions.h"
#import "PVButtonGroupOverlayView.h"

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

@property (nonatomic, strong) JSButton *menuButton;

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

- (void)dealloc
{
	self.genesisCore = nil;
	self.gameAudio = nil;
	self.glViewController = nil;
	self.dPad = nil;
	self.aButton = nil;
	self.startButton = nil;
	self.menuButton = nil;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.title = [self.romPath lastPathComponent];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(appDidBecomeActive:)
												 name:UIApplicationDidBecomeActiveNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(appWillResignActive:)
												 name:UIApplicationWillResignActiveNotification
											   object:nil];
	
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
	
	self.dPad = [[JSDPad alloc] initWithFrame:CGRectMake(5, [[self view] bounds].size.height - 185, 180, 180)];
	[self.dPad setAutoresizingMask:UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin];
	[self.dPad setDelegate:self];
	[self.dPad setAlpha:0.3];
	[self.view addSubview:self.dPad];
	
	UIView *buttonContainer = [[UIView alloc] initWithFrame:CGRectMake(([self.view bounds].size.width - 212) - 5, ([self.view bounds].size.height - 92) - 5, 212, 92)];
	[buttonContainer setAutoresizingMask:UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin];
	[self.view addSubview:buttonContainer];
	
	self.aButton = [[JSButton alloc] initWithFrame:CGRectMake(8, 24, 60, 60)];
	[[self.aButton titleLabel] setText:@"A"];
	[self.aButton setBackgroundImage:[UIImage imageNamed:@"button"]];
	[self.aButton setBackgroundImagePressed:[UIImage imageNamed:@"button-pressed"]];
	[self.aButton setDelegate:self];
	[self.aButton setAlpha:0.3];
	[buttonContainer addSubview:self.aButton];
	
	self.bButton = [[JSButton alloc] initWithFrame:CGRectMake(76, 16, 60, 60)];
	[[self.bButton titleLabel] setText:@"B"];
	[self.bButton setBackgroundImage:[UIImage imageNamed:@"button"]];
	[self.bButton setBackgroundImagePressed:[UIImage imageNamed:@"button-pressed"]];
	[self.bButton setDelegate:self];
	[self.bButton setAlpha:0.3];
	[buttonContainer addSubview:self.bButton];
	
	self.cButton = [[JSButton alloc] initWithFrame:CGRectMake(144, 8, 60, 60)];
	[[self.cButton titleLabel] setText:@"C"];
	[self.cButton setBackgroundImage:[UIImage imageNamed:@"button"]];
	[self.cButton setBackgroundImagePressed:[UIImage imageNamed:@"button-pressed"]];
	[self.cButton setDelegate:self];
	[self.cButton setAlpha:0.3];
	[buttonContainer addSubview:self.cButton];
	
	PVButtonGroupOverlayView *buttonGroup = [[PVButtonGroupOverlayView alloc] initWithButtons:@[self.aButton, self.bButton, self.cButton]];
	[buttonGroup setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
	[buttonContainer addSubview:buttonGroup];
	
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
	
	self.menuButton = [[JSButton alloc] initWithFrame:CGRectMake(([[self view] bounds].size.width - 62) / 2, [self.glViewController view].bounds.size.height + 10, 62, 22)];
	[self.menuButton setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin];
	[self.menuButton setBackgroundImage:[UIImage imageNamed:@"button-thin"]];
	[self.menuButton setBackgroundImagePressed:[UIImage imageNamed:@"button-thin-pressed"]];
	[[self.menuButton titleLabel] setText:@"Menu"];
	[[self.menuButton titleLabel] setFont:[UIFont boldSystemFontOfSize:12]];
	[self.menuButton setTitleEdgeInsets:UIEdgeInsetsMake(0, 0, 4, 0)];
	[self.menuButton setDelegate:self];
	[self.menuButton setAlpha:0.3];
	[self.view addSubview:self.menuButton];
	
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
	{
		[[self.glViewController view] setFrame:CGRectMake(([self.view bounds].size.width - 472) / 2, 0, 457, 320)];
		[self.menuButton setFrame:CGRectMake(([[self view] bounds].size.width - 62) / 2, 10, 62, 22)];
		[self.menuButton setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin];
	}
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
							 [self.menuButton setFrame:CGRectMake(([[self view] bounds].size.width - 62) / 2, [self.glViewController view].bounds.size.height + 10, 62, 22)];
							 [self.menuButton setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin];
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
							 [self.menuButton setFrame:CGRectMake(([[self view] bounds].size.width - 62) / 2, 10, 62, 22)];
							 [self.menuButton setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin];
						 }
						 completion:^(BOOL finished) {
						 }];
	}
}

- (void)appDidBecomeActive:(NSNotification *)note
{
	[self.genesisCore setPauseEmulation:NO];
}

- (void)appWillResignActive:(NSNotification *)note
{
	[self.genesisCore setPauseEmulation:YES];
}

- (void)showMenu
{
	__block PVEmulatorViewController *weakSelf = self;
	
	[self.genesisCore setPauseEmulation:YES];
	
	UIActionSheet *actionsheet = [[UIActionSheet alloc] init];
	
	[actionsheet PV_addButtonWithTitle:@"Reset" action:^{
		[self.genesisCore setPauseEmulation:NO];
		[self.genesisCore resetEmulation];
	}];
	[actionsheet PV_addButtonWithTitle:@"Quit" action:^{
		[weakSelf.gameAudio stopAudio];
		[weakSelf.genesisCore stopEmulation];
		[weakSelf dismissViewControllerAnimated:YES completion:NULL];
	}];
	[actionsheet PV_addCancelButtonWithTitle:@"Resume" action:^{
		[self.genesisCore setPauseEmulation:NO];
	}];
	[actionsheet showInView:self.view];
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
	else if ([button isEqual:self.bButton])
	{
		[self.genesisCore pushGenesisButton:PVGenesisButtonB];
	}
	else if ([button isEqual:self.cButton])
	{
		[self.genesisCore pushGenesisButton:PVGenesisButtonC];
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
	else if ([button isEqual:self.bButton])
	{
		[self.genesisCore releaseGenesisButton:PVGenesisButtonB];
	}
	else if ([button isEqual:self.cButton])
	{
		[self.genesisCore releaseGenesisButton:PVGenesisButtonC];
	}
	else if ([button isEqual:self.menuButton])
	{
		[self showMenu];
	}
}

@end
