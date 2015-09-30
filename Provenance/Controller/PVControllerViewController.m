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
#import "kICadeControllerSetting.h"
#import "PVControllerManager.h"

NSString * const PVSavedDPadFrameKey = @"PVSavedDPadFrameKey";
NSString * const PVSavedButtonFrameKey = @"PVSavedButtonFrameKey";
NSString * const PVSavedControllerFramesKey = @"PVSavedControllerFramesKey";

@interface PVControllerViewController ()

@property (nonatomic, strong) NSArray *controlLayout;

#if !TARGET_OS_TV
@property (nonatomic, strong) UIPanGestureRecognizer *dPadPanRecognizer;
@property (nonatomic, strong) UIPinchGestureRecognizer *dpadPinchRecognizer;

@property (nonatomic, strong) UIPanGestureRecognizer *buttonPanRecognizer;
@property (nonatomic, strong) UIPinchGestureRecognizer *buttonPinchRecognizer;

@property (nonatomic, strong) UIButton *saveControlsButton;
@property (nonatomic, strong) UIButton *resetControlsButton;
@property (nonatomic, strong) UIToolbar *fakeBlurView;

@property (nonatomic, assign, getter = isEditing) BOOL editing;
#endif
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
    self.iCadeController = nil;
	self.controlLayout = nil;
	self.dPad = nil;
	self.buttonGroup = nil;
	self.leftShoulderButton = nil;
	self.rightShoulderButton = nil;
	self.startButton = nil;
	self.selectButton = nil;
#if !TARGET_OS_TV
	self.saveControlsButton = nil;
	self.resetControlsButton = nil;
#endif
	self.delegate = nil;
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (!self.iCadeController)
    {
        PVSettingsModel* settings = [PVSettingsModel sharedInstance];
        self.iCadeController = kIcadeControllerSettingToPViCadeController(settings.iCadeControllerSetting);
        if (self.iCadeController)
        {
            __weak PVControllerViewController* weakSelf = self;
            self.iCadeController.controllerPressedAnyKey = ^(PViCadeController* controller) {
                [weakSelf setupGameController:weakSelf.iCadeController];
            };
        }
    }
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
        [self setupGameController:[[PVControllerManager sharedManager] player1]];
        [self setupGameController:[[PVControllerManager sharedManager] player2]];
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
        [self setupGameController:[[PVControllerManager sharedManager] player1]];
        [self setupGameController:[[PVControllerManager sharedManager] player2]];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    [self resetControls:self];
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
                
                NSDictionary *savedControllerFrames = [[[NSUserDefaults standardUserDefaults] objectForKey:PVSavedControllerFramesKey] objectForKey:self.systemIdentifier];
                NSString *savedDPadFrame = [savedControllerFrames objectForKey:PVSavedDPadFrameKey];
                if ([savedDPadFrame length])
                {
                    dPadFrame = CGRectFromString(savedDPadFrame);
                }
                
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
                
                NSDictionary *savedControllerFrames = [[[NSUserDefaults standardUserDefaults] objectForKey:PVSavedControllerFramesKey] objectForKey:self.systemIdentifier];
                NSString *savedButtonFrame = [savedControllerFrames objectForKey:PVSavedButtonFrameKey];
                if ([savedButtonFrame length])
                {
                    buttonsFrame = CGRectFromString(savedButtonFrame);
                }
                
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

- (void)editControls
{
#if !TARGET_OS_TV
	self.editing = YES;
	
	if ([self.delegate respondsToSelector:@selector(controllerViewControllerDidBeginEditing:)])
	{
		[self.delegate controllerViewControllerDidBeginEditing:self];
	}
    
    if (!self.fakeBlurView)
    {
        self.fakeBlurView = [[UIToolbar alloc] initWithFrame:[self.view bounds]];
    }
    [self.fakeBlurView setAutoresizingMask:[self.view autoresizingMask]];
    [self.fakeBlurView setBarStyle:UIBarStyleBlack];
    [self.fakeBlurView setTranslucent:YES];
    [self.fakeBlurView setAlpha:0];
    [self.view insertSubview:self.fakeBlurView atIndex:0];
    
	self.saveControlsButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[self.saveControlsButton setTitle:@"Save Controls" forState:UIControlStateNormal];
    [self.saveControlsButton sizeToFit];
    [self.saveControlsButton setWidth:[self.saveControlsButton bounds].size.width + 10];
    [self.saveControlsButton setBackgroundColor:[UIColor whiteColor]];
    [[self.saveControlsButton layer] setCornerRadius:[self.saveControlsButton bounds].size.height / 4];
    [[self.saveControlsButton layer] setBorderColor:[[self.saveControlsButton tintColor] CGColor]];
    [[self.saveControlsButton layer] setBorderWidth:1.0];
	[self.saveControlsButton setOrigin:CGPointMake(([self.view bounds].size.width - [self.saveControlsButton bounds].size.width) / 2,
												   ([self.view bounds].size.height / 2) - ([self.saveControlsButton bounds].size.height + 4))];
	[self.saveControlsButton addTarget:self action:@selector(saveControls:) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:self.saveControlsButton];
	
	self.resetControlsButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	[self.resetControlsButton setTitle:@"Reset Controls" forState:UIControlStateNormal];
    [self.resetControlsButton sizeToFit];
    [self.resetControlsButton setWidth:[self.resetControlsButton bounds].size.width + 10];
    [self.resetControlsButton setBackgroundColor:[UIColor whiteColor]];
    [[self.resetControlsButton layer] setCornerRadius:[self.resetControlsButton bounds].size.height / 4];
    [[self.resetControlsButton layer] setBorderColor:[[self.resetControlsButton tintColor] CGColor]];
    [[self.resetControlsButton layer] setBorderWidth:1.0];
	[self.resetControlsButton setOrigin:CGPointMake(([self.view bounds].size.width - [self.resetControlsButton bounds].size.width) / 2,
													([self.view bounds].size.height / 2) + 4)];//[self.resetControlsButton bounds].size.height)];
	[self.resetControlsButton addTarget:self action:@selector(resetControls:) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:self.resetControlsButton];
	
	[self.saveControlsButton setAlpha:0.0];
	[self.resetControlsButton setAlpha:0.0];
	
	[UIView animateWithDuration:0.3
						  delay:0.0
						options:UIViewAnimationOptionBeginFromCurrentState
					 animations:^{
                         [self.fakeBlurView setAlpha:1.0];
						 [self.dPad setAlpha:1.0];
						 [self.buttonGroup setAlpha:1.0];
						 [self.saveControlsButton setAlpha:1.0];
						 [self.resetControlsButton setAlpha:1.0];
					 }
					 completion:^(BOOL finished) {
						 self.dPadPanRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
																						  action:@selector(panRecognized:)];
						 self.buttonPanRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self
																							action:@selector(panRecognized:)];
						 [self.dPad addGestureRecognizer:self.dPadPanRecognizer];
						 [self.buttonGroup addGestureRecognizer:self.buttonPanRecognizer];
					 }];
#endif
}

- (void)adjustAnchorPointForRecognizer:(UIGestureRecognizer *)recognizer
{
	if ([recognizer state] == UIGestureRecognizerStateBegan)
	{
		UIView *view = [recognizer view];
		UIView *superview = [view superview];
		
        CGPoint locationInView = [recognizer locationInView:view];
        CGPoint locationInSuperview = [recognizer locationInView:superview];
		
		view.layer.anchorPoint = CGPointMake(locationInView.x / view.bounds.size.width, locationInView.y / view.bounds.size.height);
		view.center = locationInSuperview;
    }
}

- (void)panRecognized:(UIPanGestureRecognizer *)recognizer
{
	[self adjustAnchorPointForRecognizer:recognizer];
	
	if ([recognizer state] == UIGestureRecognizerStateBegan || [recognizer state] == UIGestureRecognizerStateChanged)
	{
		UIView *view = [recognizer view];
		UIView *superview = [view superview];
		
		CGPoint translation = [recognizer translationInView:superview];
		CGFloat newX = roundf([view center].x + translation.x);
		CGFloat newY = roundf([view center].y + translation.y);
		[view setCenter:CGPointMake(newX, newY)];
		[recognizer setTranslation:CGPointZero inView:superview];
	}
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
	return YES;
}

- (void)resetControls:(id)sender
{
	CGFloat xPadding = 5;
	CGFloat yPadding = 5;
    
    CGRect dPadFrame = CGRectZero;
    CGRect buttonsFrame = CGRectZero;
    
    for (NSDictionary *control in self.controlLayout)
    {
        NSString *controlType = [control objectForKey:PVControlTypeKey];
        
        if ([controlType isEqualToString:PVDPad])
        {
            CGSize size = CGSizeFromString([control objectForKey:PVControlSizeKey]);
            dPadFrame = CGRectMake(xPadding, [[self view] bounds].size.height - size.height - yPadding, size.width, size.height);
        }
        else if ([controlType isEqualToString:PVButtonGroup])
        {
            CGSize size = CGSizeFromString([control objectForKey:PVControlSizeKey]);
            buttonsFrame = CGRectMake([[self view] bounds].size.width - size.width - xPadding, [[self view] bounds].size.height - size.height - yPadding, size.width, size.height);
        }
    }
    
	[UIView animateWithDuration:0.3
						  delay:0.0
						options:UIViewAnimationOptionBeginFromCurrentState
					 animations:^{
						 [self.dPad setFrame:dPadFrame];
						 [self.buttonGroup setFrame:buttonsFrame];
					 }
					 completion:^(BOOL finished) {
					 }];
}

- (void)saveControls:(id)sender
{
#if !TARGET_OS_TV
    CGRect dPadFrame = [self.dPad frame];
    CGRect buttonsFrame = [self.buttonGroup frame];
	
    NSMutableDictionary *savedControllerFrames = [[[NSUserDefaults standardUserDefaults] objectForKey:PVSavedControllerFramesKey] mutableCopy];
    
    if (!savedControllerFrames)
    {
        savedControllerFrames = [NSMutableDictionary dictionary];
    }
    
    NSMutableDictionary *savedControllerPositionsForSystem = [NSMutableDictionary dictionary];
	[savedControllerPositionsForSystem setObject:NSStringFromCGRect(dPadFrame) forKey:PVSavedDPadFrameKey];
	[savedControllerPositionsForSystem setObject:NSStringFromCGRect(buttonsFrame) forKey:PVSavedButtonFrameKey];
    [savedControllerFrames setObject:[savedControllerPositionsForSystem copy] forKey:self.systemIdentifier];
    
    [[NSUserDefaults standardUserDefaults] setObject:[savedControllerFrames copy] forKey:PVSavedControllerFramesKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	CGFloat alpha = [[PVSettingsModel sharedInstance] controllerOpacity];
	
	[UIView animateWithDuration:0.3
						  delay:0.0
						options:UIViewAnimationOptionBeginFromCurrentState
					 animations:^{
						 [self.dPad setAlpha:alpha];
						 [self.buttonGroup setAlpha:alpha];
						 [self.saveControlsButton setAlpha:0.0];
						 [self.resetControlsButton setAlpha:0.0];
                         [self.fakeBlurView setAlpha:0.0];
					 }
					 completion:^(BOOL finished) {
						 [self.dPad removeGestureRecognizer:self.dPadPanRecognizer];
						 [self.buttonGroup removeGestureRecognizer:self.buttonPanRecognizer];
						 self.dPadPanRecognizer = nil;
						 self.buttonPanRecognizer = nil;
						 
                         [self.fakeBlurView removeFromSuperview];
						 [self.saveControlsButton removeFromSuperview];
						 [self.resetControlsButton removeFromSuperview];
						 self.saveControlsButton = nil;
						 self.resetControlsButton = nil;
						 
						self.editing = NO;
						 
						 if ([self.delegate respondsToSelector:@selector(controllerViewControllerDidEndEditing:)])
						 {
							 [self.delegate controllerViewControllerDidEndEditing:self];
						 }
					 }];
#endif
}

#pragma mark - GameController Notifications

- (void)controllerDidConnect:(NSNotification *)note
{
    if ([[PVControllerManager sharedManager] hasControllers])
    {
        [self setupGameController:[[PVControllerManager sharedManager] player1]];
        [self setupGameController:[[PVControllerManager sharedManager] player2]];
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
        [self setupGameController:[[PVControllerManager sharedManager] player1]];
        [self setupGameController:[[PVControllerManager sharedManager] player2]];
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

- (void)setupGameController:(GCController *)controller
{
    NSInteger player = -1;
    if (controller == [[PVControllerManager sharedManager] player1] || controller == self.iCadeController)
    {
        player = 0;
    }
    else if (controller == [[PVControllerManager sharedManager] player2])
    {
        player = 1;
    }

    __weak PVControllerViewController *weakSelf = self;
    [controller setControllerPausedHandler:^(GCController *controller) {
        if ([weakSelf.delegate respondsToSelector:@selector(controllerViewControllerDidPressMenuButton:)])
        {
            [weakSelf.delegate controllerViewControllerDidPressMenuButton:weakSelf];
        }
    }];

    GCControllerDirectionPad *pad;
    GCControllerDirectionPad *leftAnalog;
    GCControllerDirectionPad *rightAnalog;

	if ([controller extendedGamepad])
	{
        pad = [[controller extendedGamepad] dpad];
        
        [[[controller extendedGamepad] buttonA] setPressedChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed){
            if (pressed)
            {
                [weakSelf controllerPressedButton:PVControllerButtonA forPlayer:player];
            }
            else
            {
                [weakSelf controllerReleasedButton:PVControllerButtonA forPlayer:player];
            }
        }];
        [[[controller extendedGamepad] buttonB] setPressedChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed){
            if (pressed)
            {
                [weakSelf controllerPressedButton:PVControllerButtonB forPlayer:player];
            }
            else
            {
                [weakSelf controllerReleasedButton:PVControllerButtonB forPlayer:player];
            }
        }];
        [[[controller extendedGamepad] buttonX] setPressedChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed){
            if (pressed)
            {
                [weakSelf controllerPressedButton:PVControllerButtonX forPlayer:player];
            }
            else
            {
                [weakSelf controllerReleasedButton:PVControllerButtonX forPlayer:player];
            }
        }];
        [[[controller extendedGamepad] buttonY] setPressedChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed){
            if (pressed)
            {
                [weakSelf controllerPressedButton:PVControllerButtonY forPlayer:player];
            }
            else
            {
                [weakSelf controllerReleasedButton:PVControllerButtonY forPlayer:player];
            }
        }];
        
		leftAnalog = [[controller extendedGamepad] leftThumbstick];
        rightAnalog = [[controller extendedGamepad] rightThumbstick];
        
        [[[controller extendedGamepad] leftShoulder] setPressedChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed){
            if (pressed)
            {
                [weakSelf controllerPressedButton:PVControllerButtonLeftShoulder forPlayer:player];
            }
            else
            {
                [weakSelf controllerReleasedButton:PVControllerButtonLeftShoulder forPlayer:player];
            }
        }];
        [[[controller extendedGamepad] rightShoulder] setPressedChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed){
            if (pressed)
            {
                [weakSelf controllerPressedButton:PVControllerButtonRightShoulder forPlayer:player];
            }
            else
            {
                [weakSelf controllerReleasedButton:PVControllerButtonRightShoulder forPlayer:player];
            }
        }];
		
        [[[controller extendedGamepad] leftTrigger] setPressedChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed){
            if (pressed)
            {
                [weakSelf controllerPressedButton:PVControllerButtonLeftTrigger forPlayer:player];
            }
            else
            {
                [weakSelf controllerReleasedButton:PVControllerButtonLeftTrigger forPlayer:player];
            }
        }];
        [[[controller extendedGamepad] rightTrigger] setPressedChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed){
            if (pressed)
            {
                [weakSelf controllerPressedButton:PVControllerButtonRightTrigger forPlayer:player];
            }
            else
            {
                [weakSelf controllerReleasedButton:PVControllerButtonRightTrigger forPlayer:player];
            }
        }];
	}
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        [[controller microGamepad] setAllowsRotation:YES];
        [[controller microGamepad] setReportsAbsoluteDpadValues:YES];

        pad = [[controller microGamepad] dpad];

        // options are so limited here, mapping is so arbitrary. Most games need a start button, so just use A and Start? (Start is mapped to Left trigger for most pads) :/
        // Siri-Remote != game controller. (Sorry Apple, but it's the truth and the sooner you realise it the sooner we can get on with our lives.)

        [[[controller microGamepad] buttonA] setPressedChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed){
            if (pressed)
            {
                [weakSelf controllerPressedButton:PVControllerButtonA forPlayer:player];
            }
            else
            {
                [weakSelf controllerReleasedButton:PVControllerButtonA forPlayer:player];
            }
        }];
        [[[controller microGamepad] buttonX] setPressedChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed){
            if (pressed)
            {
                [weakSelf controllerPressedButton:PVControllerButtonB forPlayer:player];
            }
            else
            {
                [weakSelf controllerReleasedButton:PVControllerButtonB forPlayer:player];
            }
        }];
    }
#endif
	else
	{
        pad = [[controller gamepad] dpad];
        
        [[[controller gamepad] buttonA] setPressedChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed){
            if (pressed)
            {
                [weakSelf controllerPressedButton:PVControllerButtonA forPlayer:player];
            }
            else
            {
                [weakSelf controllerReleasedButton:PVControllerButtonA forPlayer:player];
            }
        }];
        [[[controller gamepad] buttonB] setPressedChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed){
            if (pressed)
            {
                [weakSelf controllerPressedButton:PVControllerButtonB forPlayer:player];
            }
            else
            {
                [weakSelf controllerReleasedButton:PVControllerButtonB forPlayer:player];
            }
        }];
        [[[controller gamepad] buttonX] setValueChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed){
            if (pressed)
            {
                [weakSelf controllerPressedButton:PVControllerButtonX forPlayer:player];
            }
            else
            {
                [weakSelf controllerReleasedButton:PVControllerButtonX forPlayer:player];
            }
        }];
        [[[controller gamepad] buttonY] setPressedChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed){
            if (pressed)
            {
                [weakSelf controllerPressedButton:PVControllerButtonY forPlayer:player];
            }
            else
            {
                [weakSelf controllerReleasedButton:PVControllerButtonY forPlayer:player];
            }
        }];
        
        [[[controller gamepad] leftShoulder] setValueChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed){
            if (pressed)
            {
                [weakSelf controllerPressedButton:PVControllerButtonLeftShoulder forPlayer:player];
            }
            else
            {
                [weakSelf controllerReleasedButton:PVControllerButtonLeftShoulder forPlayer:player];
            }
        }];
        [[[controller gamepad] rightShoulder] setPressedChangedHandler:^(GCControllerButtonInput *button, float value, BOOL pressed){
            if (pressed)
            {
                [weakSelf controllerPressedButton:PVControllerButtonRightShoulder forPlayer:player];
            }
            else
            {
                [weakSelf controllerReleasedButton:PVControllerButtonRightShoulder forPlayer:player];
            }
        }];
	}
    
    GCControllerDirectionPadValueChangedHandler dPadHandler = ^(GCControllerDirectionPad *dpad, float xValue, float yValue) {
        [weakSelf controllerDirectionValueChanged:dpad forPlayer:player];
    };
    
    [pad setValueChangedHandler:dPadHandler];
    if (leftAnalog)
    {
        [leftAnalog setValueChangedHandler:dPadHandler];
    }

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

- (void)controllerPressedButton:(PVControllerButton)button forPlayer:(NSInteger)player
{
    [self doesNotImplementOptionalSelector:_cmd];
}

- (void)controllerReleasedButton:(PVControllerButton)button forPlayer:(NSInteger)player
{
    [self doesNotImplementOptionalSelector:_cmd];
}

- (void)controllerDirectionValueChanged:(GCControllerDirectionPad *)dpad forPlayer:(NSInteger)player
{
	[self doesNotImplementOptionalSelector:_cmd];
}

@end
