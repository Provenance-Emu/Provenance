//
//  PVControllerViewController.m
//  Provenance
//
//  Created by James Addyman on 03/09/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVControllerViewController.h"
#import "PVButtonGroupOverlayView.h"
#import "Provenance-Swift.h"
#import <PVSupport/NSObject+PVAbstractAdditions.h>
#import "UIView+FrameAdditions.h"
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>
#import "PVControllerManager.h"
#import <PVSupport/PVEmulatorCore.h>
#import "UIDevice+Hardware.h"

@implementation PVControllerViewController

- (id)initWithControlLayout:(NSArray *)controlLayout systemIdentifier:(NSString *)systemIdentifier
{
	if ((self = [super initWithNibName:nil bundle:nil]))
	{
		self.controlLayout = controlLayout;
        self.systemIdentifier = systemIdentifier;
	}
	
	return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[GCController controllers] makeObjectsPerformSelector:@selector(setControllerPausedHandler:) withObject:NULL];
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

#if !TARGET_OS_TV
	if (@available(iOS 10.0, *)) {
		self.feedbackGenerator = [[UISelectionFeedbackGenerator alloc] init];
		[self.feedbackGenerator prepare];
	}

	if ([[PVControllerManager sharedManager] hasControllers])
	{
		[self hideTouchControlsFor:[[PVControllerManager sharedManager] player1]];
		[self hideTouchControlsFor:[[PVControllerManager sharedManager] player2]];
	}
#endif
}

#pragma mark - GameController Notifications

- (void)controllerDidConnect:(NSNotification *)note
{
    #if !TARGET_OS_TV
    if ([[PVControllerManager sharedManager] hasControllers])
    {
        [self hideTouchControlsFor:[[PVControllerManager sharedManager] player1]];
        [self hideTouchControlsFor:[[PVControllerManager sharedManager] player2]];
    }
    else
    {
        [self.dPad setHidden:NO];
        [self.dPad2 setHidden:self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact];
        [self.buttonGroup setHidden:NO];
        [self.leftShoulderButton setHidden:NO];
        [self.rightShoulderButton setHidden:NO];
        [self.leftShoulderButton2 setHidden:NO];
        [self.rightShoulderButton2 setHidden:NO];
        [self.startButton setHidden:NO];
        [self.selectButton setHidden:NO];
    }
    #endif
}

- (void)controllerDidDisconnect:(NSNotification *)note
{
    #if !TARGET_OS_TV
    if ([[PVControllerManager sharedManager] hasControllers])
    {
        [self hideTouchControlsFor:[[PVControllerManager sharedManager] player1]];
        [self hideTouchControlsFor:[[PVControllerManager sharedManager] player2]];
    }
    else
    {
        [self.dPad setHidden:NO];
        [self.dPad2 setHidden:self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact];
        [self.buttonGroup setHidden:NO];
        [self.leftShoulderButton setHidden:NO];
        [self.rightShoulderButton setHidden:NO];
        [self.leftShoulderButton2 setHidden:NO];
        [self.rightShoulderButton2 setHidden:NO];
        [self.startButton setHidden:NO];
        [self.selectButton setHidden:NO];
    }
    #endif
}

#pragma mark - Controller handling

- (void)dPad:(JSDPad *)dPad didPressDirection:(JSDPadDirection)direction
{
	[self vibrate];
}

- (void)dPadDidReleaseDirection:(JSDPad *)dPad
{
}

- (void)buttonPressed:(JSButton *)button
{
	[self vibrate];
}

- (void)buttonReleased:(JSButton *)button
{
}

- (void)pressStartForPlayer:(NSUInteger)player
{
	[self vibrate];
}

- (void)releaseStartForPlayer:(NSUInteger)player
{
}

- (void)pressSelectForPlayer:(NSUInteger)player
{
	[self vibrate];
}

- (void)releaseSelectForPlayer:(NSUInteger)player
{
}

// These are private/undocumented API, so we need to expose them here
// Based on GBA4iOS 2.0 by Riley Testut
// https://bitbucket.org/rileytestut/gba4ios/src/6c363f7503ecc1e29a32f6869499113c3a3a6297/GBA4iOS/GBAControllerView.m?at=master#cl-245

void AudioServicesStopSystemSound(int);
void AudioServicesPlaySystemSoundWithVibration(int, id, NSDictionary *);

- (void)vibrate
{
#if !TARGET_OS_TV
	if ([[PVSettingsModel sharedInstance] buttonVibration])
	{
		// only iPhone 7 and 7 Plus support the taptic engine APIs for now.
		// everything else should fall back to the vibration motor.
		if ([UIDevice hasTapticMotor])
		{
			[self.feedbackGenerator selectionChanged];
		}
		else
		{
			AudioServicesStopSystemSound(kSystemSoundID_Vibrate);

			NSInteger vibrationLength = 30;
			NSArray *pattern = @[@NO, @0, @YES, @(vibrationLength)];

			NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
			dictionary[@"VibePattern"] = pattern;
			dictionary[@"Intensity"] = @1;

			AudioServicesPlaySystemSoundWithVibration(kSystemSoundID_Vibrate, nil, dictionary);
		}
	}
#endif
}

@end
