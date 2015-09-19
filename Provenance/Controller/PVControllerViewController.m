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

	[self.gameController setControllerPausedHandler:NULL];
    self.emulatorCore = nil;
    self.systemIdentifier = nil;
	self.gameController = nil;
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

-(void) viewDidAppear:(BOOL) animated {
    [super viewDidAppear:animated];
    
    if (!self.iCadeController) {
        PVSettingsModel* settings = [PVSettingsModel sharedInstance];
        self.iCadeController = kIcadeControllerSettingToPViCadeController(settings.iCadeControllerSetting);
        if (self.iCadeController) {
            __weak PVControllerViewController* weakSelf = self;
            self.iCadeController.controllerPressedAnyKey = ^(PViCadeController* controller) {
                if (!weakSelf.gameController) {
                    weakSelf.gameController = controller;
                    [weakSelf setupGameController];
                }
            };
        }
    }
}

- (GCController *)getBestGamepad:(NSArray *)controllers
{
    for (GCController *controller in controllers) {
        if (controller.extendedGamepad) {
            return controller;
        }
    }
    for (GCController *controller in controllers) {
        if (controller.gamepad) {
            return controller;
        }
    }
    return [controllers firstObject];
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
	
	
	if ([[GCController controllers] count])
	{
        self.gameController = [self getBestGamepad:[GCController controllers]];
	}
	else
	{
		[GCController startWirelessControllerDiscoveryWithCompletionHandler:^{
			if ([[GCController controllers] count] == 0)
			{
				DLog(@"No controllers found");
			}
		}];
	}
	
	if (self.gameController)
	{
		[self setupGameController];
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
    if (self.gameController)
    {
        [self setupGameController];
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
	// just use the first controller that connects - we're not doing multiplayer
	// if we already have a game controller, ignore this notification
	if (!self.gameController)
	{
        self.gameController = [self getBestGamepad:[GCController controllers]];
		[GCController stopWirelessControllerDiscovery];
		
		[self setupGameController];
	}
}

- (void)controllerDidDisconnect:(NSNotification *)note
{
	GCController *controller = (GCController *)[note object];
	if ([controller isEqual:self.gameController])
	{
		self.gameController = nil;
		[self.leftShoulderButton setHidden:NO];
		[self.rightShoulderButton setHidden:NO];
		[self.dPad setHidden:NO];
		[self.buttonGroup setHidden:NO];
		[self.startButton setHidden:NO];
		[self.selectButton setHidden:NO];
	}
    if ([[GCController controllers] count]) {
        self.gameController = [self getBestGamepad:[GCController controllers]];
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

- (void)setupGameController
{
    __weak PVControllerViewController *weakSelf = self;
    [self.gameController setControllerPausedHandler:^(GCController *controller) {
        if ([weakSelf.delegate respondsToSelector:@selector(controllerViewControllerDidPressMenuButton:)])
        {
            [weakSelf.delegate controllerViewControllerDidPressMenuButton:weakSelf];
        }
    }];
    
    NSArray *buttons = nil;
    
	if ([self.gameController extendedGamepad])
	{
        _pad = [[self.gameController extendedGamepad] dpad];
        
		_a = [[self.gameController extendedGamepad] buttonA];
		_b = [[self.gameController extendedGamepad] buttonB];
		_x = [[self.gameController extendedGamepad] buttonX];
		_y = [[self.gameController extendedGamepad] buttonY];
        
		_leftAnalog = [[self.gameController extendedGamepad] leftThumbstick];
        _rightAnalog = [[self.gameController extendedGamepad] rightThumbstick];
        
		_leftShoulder = [[self.gameController extendedGamepad] leftShoulder];
		_rightShoulder = [[self.gameController extendedGamepad] rightShoulder];
		
        _leftTrigger = [[self.gameController extendedGamepad] leftTrigger];
		_rightTrigger = [[self.gameController extendedGamepad] rightTrigger];
        
        buttons = @[_a, _b, _x, _y, _leftShoulder, _rightShoulder, _leftTrigger, _rightTrigger];
	}
#if TARGET_OS_TV
    else if ([self.gameController microGamepad])
    {
        [[self.gameController microGamepad] setAllowsRotation:YES];

        _pad = [[self.gameController microGamepad] dpad];

        _a = [[self.gameController microGamepad] buttonA];
        _b = [[self.gameController microGamepad] buttonX];

        buttons = @[_a, _b];
    }
#endif
	else
	{
        _pad = [[self.gameController gamepad] dpad];
        
        _a = [[self.gameController gamepad] buttonA];
        _b = [[self.gameController gamepad] buttonB];
        _x = [[self.gameController gamepad] buttonX];
        _y = [[self.gameController gamepad] buttonY];
        
        _leftShoulder = [[self.gameController gamepad] leftShoulder];
        _rightShoulder = [[self.gameController gamepad] rightShoulder];
        
        buttons = @[_a, _b, _x, _y, _leftShoulder, _rightShoulder];
	}
    
    GCControllerDirectionPadValueChangedHandler dPadHandler = ^(GCControllerDirectionPad *dpad, float xValue, float yValue) {
        if ((xValue != 0) || (yValue != 0))
        {
            [weakSelf gamepadPressedDirection:dpad];
        }
        else
        {
            [weakSelf gamepadReleasedDirection:dpad];
        }
    };
    
    [_pad setValueChangedHandler:dPadHandler];
    if (_leftAnalog)
    {
        [_leftAnalog setValueChangedHandler:dPadHandler];
    }
    
    GCControllerButtonValueChangedHandler buttonHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed){
        if (value > 0)
        {
            [weakSelf gamepadButtonPressed:button];
        }
        else
        {
            [weakSelf gamepadButtonReleased:button];
        }
    };
    
    [buttons makeObjectsPerformSelector:@selector(setValueChangedHandler:)
                             withObject:buttonHandler];
    
    [self.dPad setHidden:YES];
    [self.buttonGroup setHidden:YES];
    [self.leftShoulderButton setHidden:YES];
    [self.rightShoulderButton setHidden:YES];
    
    if ([self.gameController extendedGamepad])
    {
        [self.startButton setHidden:YES];
        [self.selectButton setHidden:YES];
    }
}

- (void)gamepadButtonPressed:(GCControllerButtonInput *)button
{
	[self doesNotImplementOptionalSelector:_cmd];
}

- (void)gamepadButtonReleased:(GCControllerButtonInput *)button
{
	[self doesNotImplementOptionalSelector:_cmd];
}

- (void)gamepadPressedDirection:(GCControllerDirectionPad *)dpad
{
	[self doesNotImplementOptionalSelector:_cmd];
}

- (void)gamepadReleasedDirection:(GCControllerDirectionPad *)dpad
{
	[self doesNotImplementOptionalSelector:_cmd];
}

@end
