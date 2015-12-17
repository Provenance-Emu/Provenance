//
//  PVControllerViewController.m
//  Provenance
//
//  Created by James Addyman on 03/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVControllerViewController.h"
#import "PVEmulatorConfiguration.h"
#import "PVButtonGroupOverlayView.h"
#import "PVSettingsModel.h"
#import "NSObject+PVAbstractAdditions.h"
#import "UIView+FrameAdditions.h"
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>
#import "PVControllerManager.h"
#import "PVEmulatorCore.h"
#import "PVEmulatorConstants.h"

@interface PVControllerViewController ()

@property (nonatomic, strong) NSArray *controlLayout;
@property (nonatomic, assign) BOOL touchControlsSetup;

@end

@implementation PVControllerViewController

- (id)initWithControlLayout:(NSArray *)controlLayout systemIdentifier:(NSString *)systemIdentifier
{
	if ((self = [super initWithNibName:nil bundle:nil]))
	{
		self.controlLayout = controlLayout;
        self.systemIdentifier = systemIdentifier;
        self.touchControlsSetup = NO;
	}
	
	return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [[GCController controllers] makeObjectsPerformSelector:@selector(setControllerPausedHandler:) withObject:NULL];
    self.emulatorCore = nil;
    self.systemIdentifier = nil;
    self.controlLayout = nil;
	self.dPad = nil;
	self.buttonGroup = nil;
	self.leftShoulderButton = nil;
	self.rightShoulderButton = nil;
	self.startButton = nil;
	self.selectButton = nil;
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(controllerDidConnect:)
												 name:GCControllerDidConnectNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(controllerDidDisconnect:)
												 name:GCControllerDidDisconnectNotification
											   object:nil];

    if ([[PVControllerManager sharedManager] hasControllers])
    {
        [self hideTouchControlsForController:[[PVControllerManager sharedManager] player1]];
        [self hideTouchControlsForController:[[PVControllerManager sharedManager] player2]];
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskLandscape;
}

- (void)didMoveToParentViewController:(UIViewController *)parent
{
	[super didMoveToParentViewController:parent];
	
	[self.view setFrame:[[self.view superview] bounds]];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    [self setupTouchControls];

    if ([[PVControllerManager sharedManager] hasControllers])
    {
        [self hideTouchControlsForController:[[PVControllerManager sharedManager] player1]];
        [self hideTouchControlsForController:[[PVControllerManager sharedManager] player2]];
    }
}

# pragma mark - Controller Position And Size Editing

- (void)setupTouchControls
{
#if !TARGET_OS_TV
    if (!self.touchControlsSetup)
    {
        self.touchControlsSetup = YES;
        CGFloat alpha = [[PVSettingsModel sharedInstance] controllerOpacity];
        
        for (NSDictionary *control in self.controlLayout)
        {
            NSString *controlType = [control objectForKey:PVControlTypeKey];
            
            if ([controlType isEqualToString:PVDPad])
            {
                CGFloat xPadding = 5;
                CGFloat yPadding = 5;
                CGSize size = CGSizeFromString([control objectForKey:PVControlSizeKey]);
                CGRect dPadFrame = CGRectMake(xPadding, [[self view] bounds].size.height - size.height - yPadding, size.width, size.height);

                if (!self.dPad)
                {
                    self.dPad = [[JSDPad alloc] initWithFrame:dPadFrame];
                    [self.dPad setDelegate:self];
                    [self.dPad setAlpha:alpha];
                    [self.dPad setAutoresizingMask:UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin];
                    [self.view addSubview:self.dPad];
                }
                else
                {
                    [self.dPad setFrame:dPadFrame];
                }
            }
            else if ([controlType isEqualToString:PVButtonGroup])
            {
                CGFloat xPadding = 5;
                CGFloat yPadding = 5;
                CGSize size = CGSizeFromString([control objectForKey:PVControlSizeKey]);
                CGRect buttonsFrame = CGRectMake([[self view] bounds].size.width - size.width - xPadding, [[self view] bounds].size.height - size.height - yPadding, size.width, size.height);

                if (!self.buttonGroup)
                {
                    self.buttonGroup = [[UIView alloc] initWithFrame:buttonsFrame];
                    [self.buttonGroup setAutoresizingMask:UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin];
                    
                    NSArray *groupedButtons = [control objectForKey:PVGroupedButtonsKey];
                    for (NSDictionary *groupedButton in groupedButtons)
                    {
                        CGRect buttonFrame = CGRectFromString([groupedButton objectForKey:PVControlFrameKey]);
                        JSButton *button = [[JSButton alloc] initWithFrame:buttonFrame];
                        [[button titleLabel] setText:[groupedButton objectForKey:PVControlTitleKey]];
                        [button setBackgroundImage:[UIImage imageNamed:@"button"]];
                        [button setBackgroundImagePressed:[UIImage imageNamed:@"button-pressed"]];
                        [button setDelegate:self];
                        [self.buttonGroup addSubview:button];
                    }
                    
                    PVButtonGroupOverlayView *buttonOverlay = [[PVButtonGroupOverlayView alloc] initWithButtons:[self.buttonGroup subviews]];
                    [buttonOverlay setSize:[self.buttonGroup bounds].size];
                    [self.buttonGroup addSubview:buttonOverlay];
                    [self.buttonGroup setAlpha:alpha];
                    [self.view addSubview:self.buttonGroup];
                }
                else
                {
                    [self.buttonGroup setFrame:buttonsFrame];
                }
            }
            else if ([controlType isEqualToString:PVLeftShoulderButton])
            {
                CGFloat xPadding = 10;
                CGFloat yPadding = 10;
                CGSize size = CGSizeFromString([control objectForKey:PVControlSizeKey]);
                CGRect leftShoulderFrame = CGRectMake(xPadding, yPadding, size.width, size.height);
                
                if (!self.leftShoulderButton)
                {
                    self.leftShoulderButton = [[JSButton alloc] initWithFrame:leftShoulderFrame];
                    [[self.leftShoulderButton titleLabel] setText:[control objectForKey:PVControlTitleKey]];
                    [self.leftShoulderButton setBackgroundImage:[UIImage imageNamed:@"button-thin"]];
                    [self.leftShoulderButton setBackgroundImagePressed:[UIImage imageNamed:@"button-thin-pressed"]];
                    [self.leftShoulderButton setDelegate:self];
                    [self.leftShoulderButton setTitleEdgeInsets:UIEdgeInsetsMake(0, 0, 4, 0)];
                    [self.leftShoulderButton setAlpha:alpha];
                    [self.leftShoulderButton setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin];
                    [self.view addSubview:self.leftShoulderButton];
                }
                else
                {
                    [self.leftShoulderButton setFrame:leftShoulderFrame];
                }
            }
            else if ([controlType isEqualToString:PVRightShoulderButton])
            {
                CGFloat xPadding = 10;
                CGFloat yPadding = 10;
                CGSize size = CGSizeFromString([control objectForKey:PVControlSizeKey]);
                CGRect rightShoulderFrame = CGRectMake(self.view.frame.size.width - size.width - xPadding, yPadding, size.width, size.height);
                
                if (!self.rightShoulderButton)
                {
                    self.rightShoulderButton = [[JSButton alloc] initWithFrame:rightShoulderFrame];
                    [[self.rightShoulderButton titleLabel] setText:[control objectForKey:PVControlTitleKey]];
                    [self.rightShoulderButton setBackgroundImage:[UIImage imageNamed:@"button-thin"]];
                    [self.rightShoulderButton setBackgroundImagePressed:[UIImage imageNamed:@"button-thin-pressed"]];
                    [self.rightShoulderButton setDelegate:self];
                    [self.rightShoulderButton setTitleEdgeInsets:UIEdgeInsetsMake(0, 0, 4, 0)];
                    [self.rightShoulderButton setAlpha:alpha];
                    [self.rightShoulderButton setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin];
                    [self.view addSubview:self.rightShoulderButton];
                }
                else
                {
                    [self.rightShoulderButton setFrame:rightShoulderFrame];
                }
            }
            else if ([controlType isEqualToString:PVStartButton])
            {
                CGFloat yPadding = 10;
                CGSize size = CGSizeFromString([control objectForKey:PVControlSizeKey]);
                CGRect startFrame = CGRectMake((self.view.frame.size.width - size.width) / 2, self.view.frame.size.height - size.height - yPadding, size.width, size.height);
                
                if (!self.startButton)
                {
                    self.startButton = [[JSButton alloc] initWithFrame:startFrame];
                    [[self.startButton titleLabel] setText:[control objectForKey:PVControlTitleKey]];
                    [self.startButton setBackgroundImage:[UIImage imageNamed:@"button-thin"]];
                    [self.startButton setBackgroundImagePressed:[UIImage imageNamed:@"button-thin-pressed"]];
                    [self.startButton setDelegate:self];
                    [self.startButton setTitleEdgeInsets:UIEdgeInsetsMake(0, 0, 4, 0)];
                    [self.startButton setAlpha:alpha];
                    [self.startButton setAutoresizingMask:UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin];
                    [self.view addSubview:self.startButton];
                }
                else
                {
                    [self.startButton setFrame:startFrame];
                }
            }
            else if ([controlType isEqualToString:PVSelectButton])
            {
                CGFloat yPadding = 10;
                CGSize size = CGSizeFromString([control objectForKey:PVControlSizeKey]);
                CGRect selectFrame = CGRectMake((self.view.frame.size.width - size.width) / 2, self.view.frame.size.height - (size.height * 2) - (yPadding * 2), size.width, size.height);
                
                if (!self.selectButton)
                {
                    self.selectButton = [[JSButton alloc] initWithFrame:selectFrame];
                    [[self.selectButton titleLabel] setText:[control objectForKey:PVControlTitleKey]];
                    [self.selectButton setBackgroundImage:[UIImage imageNamed:@"button-thin"]];
                    [self.selectButton setBackgroundImagePressed:[UIImage imageNamed:@"button-thin-pressed"]];
                    [self.selectButton setDelegate:self];
                    [self.selectButton setTitleEdgeInsets:UIEdgeInsetsMake(0, 0, 4, 0)];
                    [self.selectButton setAlpha:alpha];
                    [self.selectButton setAutoresizingMask:UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin];
                    [self.view addSubview:self.selectButton];
                }
                else
                {
                    [self.selectButton setFrame:selectFrame];
                }
            }
        }
    }
#endif
}

#pragma mark - GameController Notifications

- (void)controllerDidConnect:(NSNotification *)note
{
    if ([[PVControllerManager sharedManager] hasControllers])
    {
        [self hideTouchControlsForController:[[PVControllerManager sharedManager] player1]];
        [self hideTouchControlsForController:[[PVControllerManager sharedManager] player2]];
    }
    else
    {
        [self.dPad setHidden:NO];
        [self.buttonGroup setHidden:NO];
        [self.leftShoulderButton setHidden:NO];
        [self.rightShoulderButton setHidden:NO];
        [self.startButton setHidden:NO];
        [self.selectButton setHidden:NO];
    }
}

- (void)controllerDidDisconnect:(NSNotification *)note
{
    if ([[PVControllerManager sharedManager] hasControllers])
    {
        [self hideTouchControlsForController:[[PVControllerManager sharedManager] player1]];
        [self hideTouchControlsForController:[[PVControllerManager sharedManager] player2]];
    }
    else
    {
        [self.dPad setHidden:NO];
        [self.buttonGroup setHidden:NO];
        [self.leftShoulderButton setHidden:NO];
        [self.rightShoulderButton setHidden:NO];
        [self.startButton setHidden:NO];
        [self.selectButton setHidden:NO];
    }
}

#pragma mark - Controller handling

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
	[self doesNotImplementSelector:_cmd];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
	[self doesNotImplementSelector:_cmd];
}

- (void)buttonPressed:(JSButton *)button
{
	[self doesNotImplementSelector:_cmd];
}

- (void)buttonReleased:(JSButton *)button
{
	[self doesNotImplementSelector:_cmd];
}

- (void)pressStartForPlayer:(NSUInteger)player
{
    [self doesNotImplementOptionalSelector:_cmd];
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
    [self doesNotImplementOptionalSelector:_cmd];
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
    [self doesNotImplementOptionalSelector:_cmd];
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
    [self doesNotImplementOptionalSelector:_cmd];
}

// These are private/undocumented API, so we need to expose them here
// Based on GBA4iOS 2.0 by Riley Testut
// https://bitbucket.org/rileytestut/gba4ios/src/6c363f7503ecc1e29a32f6869499113c3a3a6297/GBA4iOS/GBAControllerView.m?at=master#cl-245

void AudioServicesStopSystemSound(int);
void AudioServicesPlaySystemSoundWithVibration(int, id, NSDictionary *);

- (void)vibrate
{
    AudioServicesStopSystemSound(kSystemSoundID_Vibrate);
    
    if ([[PVSettingsModel sharedInstance] buttonVibration])
    {
        NSInteger vibrationLength = 30;
        NSArray *pattern = @[@NO, @0, @YES, @(vibrationLength)];
        
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        dictionary[@"VibePattern"] = pattern;
        dictionary[@"Intensity"] = @1;
        
        AudioServicesPlaySystemSoundWithVibration(kSystemSoundID_Vibrate, nil, dictionary);
    }
}

#pragma mark -

- (void)hideTouchControlsForController:(GCController *)controller
{
    [self.dPad setHidden:YES];
    [self.buttonGroup setHidden:YES];
    [self.leftShoulderButton setHidden:YES];
    [self.rightShoulderButton setHidden:YES];
    
    if ([controller extendedGamepad])
    {
        [self.startButton setHidden:YES];
        [self.selectButton setHidden:YES];
    }
}

@end
