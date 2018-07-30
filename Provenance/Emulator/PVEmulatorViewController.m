//
//  PVEmulatorViewController.m
//  Provenance
//
//  Created by James Addyman on 14/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVEmulatorViewController.h"
#import "PVGLViewController.h"
@import PVSupport;
#import "Provenance-Swift.h"
#import "UIActionSheet+BlockAdditions.h"
#import "UIView+FrameAdditions.h"
#import <QuartzCore/QuartzCore.h>
#import "PViCade8BitdoController.h"

@interface PVEmulatorViewController () <PVAudioDelegate>

@property (nonatomic, strong) PVGLViewController *glViewController;
@property (nonatomic, strong) OEGameAudio *gameAudio;
@property (nonatomic, strong) PVControllerViewController *controllerViewController;

@property (nonatomic, assign) NSTimer *fpsTimer;
@property (nonatomic, strong) UILabel *fpsLabel;

@property (nonatomic, strong) UIScreen *secondaryScreen;
@property (nonatomic, strong) UIWindow *secondaryWindow;
@property (nonatomic, strong) UITapGestureRecognizer *menuGestureRecognizer;

@end

static __unsafe_unretained PVEmulatorViewController *_staticEmulatorViewController;

@implementation PVEmulatorViewController

void uncaughtExceptionHandler(NSException *exception)
{
	[_staticEmulatorViewController.emulatorCore autoSaveState];
}

+ (void)initialize
{
	if ([[PVSettingsModel sharedInstance] autoSave])
	{
		NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
	}
}

- (instancetype)initWithGame:(PVGame *)game;
{
	if ((self = [super init]))
	{
		_staticEmulatorViewController = self;
		self.game = game;
	}
	
	return self;
}

- (void)dealloc
{
    [self.emulatorCore stopEmulation]; //Leave emulation loop first
    [self.gameAudio stopAudio];

	NSSetUncaughtExceptionHandler(NULL);
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	_staticEmulatorViewController = nil;
	
	[self.controllerViewController willMoveToParentViewController:nil];
	[[self.controllerViewController view] removeFromSuperview];
	[self.controllerViewController removeFromParentViewController];
	
	[self.glViewController willMoveToParentViewController:nil];
	[[self.glViewController view] removeFromSuperview];
	[self.glViewController removeFromParentViewController];
	
#if !TARGET_OS_TV
	for (GCController *controller in [GCController controllers])
	{
		[controller setControllerPausedHandler:nil];
	}
#endif
    
    [self updatePlayedDuration];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
    
	self.title = [self.game title];
	
	[self.view setBackgroundColor:[UIColor blackColor]];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(appWillEnterForeground:)
												 name:UIApplicationWillEnterForegroundNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(appDidEnterBackground:)
												 name:UIApplicationDidEnterBackgroundNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(appWillResignActive:)
												 name:UIApplicationWillResignActiveNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(appDidBecomeActive:)
												 name:UIApplicationDidBecomeActiveNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(controllerDidConnect:)
												 name:GCControllerDidConnectNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(controllerDidDisconnect:)
												 name:GCControllerDidDisconnectNotification
											   object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(screenDidConnect:)
                                                 name:UIScreenDidConnectNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(screenDidDisconnect:)
                                                 name:UIScreenDidDisconnectNotification
                                               object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleControllerManagerControllerReassigned:)
												 name:PVControllerManagerControllerReassignedNotification
											   object:nil];

    self.emulatorCore = [PVCoreFactory emulatorCoreForGame:self.game];
    self.emulatorCore.audioDelegate = self;
    [self.emulatorCore setSaveStatesPath:[self saveStatePath]];
	[self.emulatorCore setBatterySavesPath:[self batterySavesPath]];
    [self.emulatorCore setBIOSPath:self.BIOSPath];
    [self.emulatorCore setController1:[[PVControllerManager sharedManager] player1]];
    [self.emulatorCore setController2:[[PVControllerManager sharedManager] player2]];
	
    NSURL *romPath = self.game.file.url;
    NSString *md5Hash = self.game.md5Hash;

    self.emulatorCore.romMD5 = md5Hash;
    self.emulatorCore.romSerial = [self.game romSerial];
    
	self.glViewController = [[PVGLViewController alloc] initWithEmulatorCore:self.emulatorCore];

        // Load now. Moved here becauase Mednafen needed to know what kind of game it's working with in order
        // to provide the correct data for creating views.
    NSURL *m3uFile = [PVEmulatorConfiguration m3uFileForGame:self.game];
    if (m3uFile) {
        romPath = m3uFile;
    }
    
    NSError *error;
    BOOL loaded = [self.emulatorCore loadFileAtPath:romPath.path error:&error];

    if(!loaded) {
        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:error.localizedDescription
                                            message:error.localizedRecoverySuggestion
                                     preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        
        if(error.code == PVEmulatorCoreErrorCodeMissingM3U) {
            [alert addAction:[UIAlertAction actionWithTitle:@"View Wiki" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://bitly.com/provm3u"]];
            }]];
        }
        
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf presentViewController:alert
                                   animated:YES
                                 completion:nil];
        });
        return;
    }
    
    if ([[UIScreen screens] count] > 1)
    {
        self.secondaryScreen = [[UIScreen screens] objectAtIndex:1];
        self.secondaryWindow = [[UIWindow alloc] initWithFrame:[self.secondaryScreen bounds]];
        [self.secondaryWindow setScreen:self.secondaryScreen];
        [self.secondaryWindow setRootViewController:self.glViewController];
        [[self.glViewController view] setFrame:[self.secondaryWindow bounds]];
        [self.secondaryWindow addSubview:[self.glViewController view]];
        [self.secondaryWindow setHidden:NO];
    }
    else
    {
        [self addChildViewController:self.glViewController];
        [self.view addSubview:[self.glViewController view]];
        [self.glViewController didMoveToParentViewController:self];
    }

    #if !TARGET_OS_TV
	self.controllerViewController = [PVCoreFactory controllerViewControllerForSystemIdentifier:[self.game systemIdentifier]];
	[self.controllerViewController setEmulatorCore:self.emulatorCore];
	[self addChildViewController:self.controllerViewController];
	[self.view addSubview:[self.controllerViewController view]];
	[self.controllerViewController didMoveToParentViewController:self];
    #endif
    
	CGFloat alpha = [[PVSettingsModel sharedInstance] controllerOpacity];
	self.menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[self.menuButton setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin| UIViewAutoresizingFlexibleBottomMargin];
	[self.menuButton setBackgroundImage:[UIImage imageNamed:@"button-menu"] forState:UIControlStateNormal];
	[self.menuButton setBackgroundImage:[UIImage imageNamed:@"button-menu-pressed"] forState:UIControlStateHighlighted];
	//[self.menuButton setTitle:@"Menu" forState:UIControlStateNormal];
	[[self.menuButton titleLabel] setShadowOffset:CGSizeMake(0, 1)];
	[self.menuButton setTitleShadowColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
	[[self.menuButton titleLabel] setFont:[UIFont boldSystemFontOfSize:12]];
	[self.menuButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[self.menuButton setAlpha:alpha];
	[self.menuButton addTarget:self action:@selector(showMenu:) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:self.menuButton];
    
    if ([[PVSettingsModel sharedInstance] showFPSCount]) {
        _fpsLabel = [UILabel new];
        _fpsLabel.textColor = [UIColor yellowColor];
        _fpsLabel.text = [NSNumber numberWithInteger:self.glViewController.framesPerSecond].stringValue;
        _fpsLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _fpsLabel.textAlignment = NSTextAlignmentRight;
#if TARGET_OS_TV
        _fpsLabel.font = [UIFont systemFontOfSize:100 weight:UIFontWeightBold];
#else
        _fpsLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
#endif
        [self.glViewController.view addSubview:_fpsLabel];
        
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_fpsLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.glViewController.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:30]];
        
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_fpsLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.glViewController.view attribute:NSLayoutAttributeRight multiplier:1.0 constant:-40]];
        
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"10.0")) {
            // Block-based NSTimer method is only available on iOS 10 and later
            self.fpsTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
                if (self.emulatorCore.renderFPS == self.emulatorCore.emulationFPS) {
                    self.fpsLabel.text = [NSString stringWithFormat:@"%2.02f", self.emulatorCore.renderFPS];
                } else {
                    self.fpsLabel.text = [NSString stringWithFormat:@"%2.02f (%2.02f)", self.emulatorCore.renderFPS, self.emulatorCore.emulationFPS];
                }
            }];
        } else {
#endif
            // Use traditional scheduledTimerWithTimeInterval method on older version of iOS
            self.fpsTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateFPSLabel) userInfo:nil repeats:YES];
            [self.fpsTimer fire];
        }
        
    }
    
#if !TARGET_OS_SIMULATOR
	if ([[GCController controllers] count])
	{
		[self.menuButton setHidden:YES];
	}
#endif

    if (!loaded)
    {
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            DLog(@"Unable to load ROM at %@", [self.game romPath]);
#if !TARGET_OS_TV
            [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
#endif
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Unable to load ROM"
                                                                                     message:@"Maybe it's corrupt? Try deleting and reimporting it."
                                                                              preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [weakSelf dismissViewControllerAnimated:YES completion:NULL];
            }]];
            [weakSelf presentViewController:alertController animated:YES completion:NULL];
        });

        return;
    }

    [self.emulatorCore startEmulation];

    self.gameAudio = [[OEGameAudio alloc] initWithCore:self.emulatorCore];
    [self.gameAudio setVolume:[[PVSettingsModel sharedInstance] volume]];
    [self.gameAudio setOutputDeviceID:0];
    [self.gameAudio startAudio];

	NSString *saveStatePath = [self saveStatePath];
	NSString *autoSavePath = [saveStatePath stringByAppendingPathComponent:@"auto.svs"];
	if ([[NSFileManager defaultManager] fileExistsAtPath:autoSavePath])
	{
		BOOL shouldAskToLoadSaveState = [[PVSettingsModel sharedInstance] askToAutoLoad];
		BOOL shouldAutoLoadSaveState = [[PVSettingsModel sharedInstance] autoLoadAutoSaves];
		
		__weak PVEmulatorViewController *weakSelf = self;
		
		if (shouldAutoLoadSaveState)
		{
			[weakSelf.emulatorCore loadStateFromFileAtPath:autoSavePath];
		}
		else if (shouldAskToLoadSaveState)
		{
			[self.emulatorCore setPauseEmulation:YES];
			
			UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Autosave file detected"
                                                                           message:@"Would you like to load it?"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Yes"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                        [weakSelf.emulatorCore loadStateFromFileAtPath:autoSavePath];
                                                        [weakSelf.emulatorCore setPauseEmulation:NO];
                                                    }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"Yes, and stop asking"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                        [weakSelf.emulatorCore loadStateFromFileAtPath:autoSavePath];
                                                        [[PVSettingsModel sharedInstance] setAutoSave:YES];
                                                        [[PVSettingsModel sharedInstance] setAskToAutoLoad:NO];
                                                    }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"No"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                        [weakSelf.emulatorCore setPauseEmulation:NO];
                                                    }]];
            [alert addAction:[UIAlertAction actionWithTitle:@"No, and stop asking"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                        [weakSelf.emulatorCore setPauseEmulation:NO];
                                                        [[PVSettingsModel sharedInstance] setAskToAutoLoad:NO];
                                                        [[PVSettingsModel sharedInstance] setAutoLoadAutoSaves:NO];
                                                    }]];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[self presentViewController:alert animated:YES completion:NULL];
			});
		}
	}

	// stupid bug in tvOS 9.2
	// the controller paused handler (if implemented) seems to cause a 'back' navigation action
	// as well as calling the pause handler itself. Which breaks the menu functionality.
	// But of course, this isn't the case on iOS 9.3. YAY FRAGMENTATION. ¬_¬

	// Conditionally handle the pause menu differently dependning on tvOS or iOS. FFS.
#if TARGET_OS_TV
    // Adding a tap gesture recognizer for the menu type will override the default 'back' functionality of tvOS
    if (!_menuGestureRecognizer) {
        _menuGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(controllerPauseButtonPressed:)];
        _menuGestureRecognizer.allowedPressTypes = @[@(UIPressTypeMenu)];
    }
    
    [self.view addGestureRecognizer:_menuGestureRecognizer];
#else
	__weak PVEmulatorViewController *weakSelf = self;
	for (GCController *controller in [GCController controllers])
	{
		[controller setControllerPausedHandler:^(GCController * _Nonnull controller) {
			[weakSelf controllerPauseButtonPressed: controller];
		}];
	}
#endif
}

#if !TARGET_OS_TV && !TARGET_OS_SIMULATOR
//Check Controller Manager if it has a Controller connected and thus if Home Indicator should hide…
-(BOOL)prefersHomeIndicatorAutoHidden{
	BOOL shouldHideHomeIndicator = [[PVControllerManager sharedManager] hasControllers];
	return shouldHideHomeIndicator;
}
#endif

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    UIEdgeInsets safeArea = UIEdgeInsetsZero;
    if (@available(iOS 11.0, tvOS 11.0, *)) {
        safeArea = self.view.safeAreaInsets;
    }
    
    CGRect frame = CGRectMake(([[self view] bounds].size.width - 62) / 2, safeArea.top + 10, 62, 22);
    [self.menuButton setFrame:frame];
}

- (NSString *)documentsPath
{
#if TARGET_OS_TV
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    
    return documentsDirectoryPath;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures
{
    return UIRectEdgeBottom;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (void)appWillEnterForeground:(NSNotification *)note
{
    [self updatePlayedDuration];
}

- (void)appDidEnterBackground:(NSNotification *)note
{
    [self updatePlayedDuration];
}

- (void)appWillResignActive:(NSNotification *)note
{
    [self.emulatorCore autoSaveState];
    [self.gameAudio pauseAudio];
    [self showMenu:self];
}

- (void)appDidBecomeActive:(NSNotification *)note
{
    if (!self.isShowingMenu)
    {
        [self.emulatorCore setPauseEmulation:NO];
    }
    
    [self.emulatorCore setShouldResyncTime:YES];
    [self.gameAudio startAudio];
}

- (void)enableContorllerInput:(BOOL)enabled {
#if TARGET_OS_TV
    self.controllerUserInteractionEnabled = enabled;
#else
// Can enable when we change to iOS 10 base
// and change super class to GCEventViewController
//    if (@available(iOS 10, *)) {
//        self.controllerUserInteractionEnabled = enabled;
//    }
#endif
}

- (void)showMenu:(id)sender
{
    [self enableContorllerInput:YES];

	__block PVEmulatorViewController *weakSelf = self;
	
	[self.emulatorCore setPauseEmulation:YES];
	self.isShowingMenu = YES;
	
    UIAlertController *actionsheet = [UIAlertController alertControllerWithTitle:nil
                                                                         message:nil
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    if (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        [[actionsheet popoverPresentationController] setSourceView:self.menuButton];
        [[actionsheet popoverPresentationController] setSourceRect:[self.menuButton bounds]];
    }

    self.menuActionSheet = actionsheet;
	
	if ([[PVControllerManager sharedManager] iCadeController])
	{
        [actionsheet addAction:[UIAlertAction actionWithTitle:@"Disconnect iCade" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[NSNotificationCenter defaultCenter] postNotificationName:GCControllerDidDisconnectNotification object:[[PVControllerManager sharedManager] iCadeController]];
            [weakSelf.emulatorCore setPauseEmulation:NO];
            weakSelf.isShowingMenu = NO;
            [weakSelf enableContorllerInput:NO];
		}]];
    }

    PVControllerManager *controllerManager = [PVControllerManager sharedManager];
	BOOL wantsStartSelectInMenu = [PVEmulatorConfiguration systemIDWantsStartAndSelectInMenu: self.systemID];
	
	if ([controllerManager player1]) {
		if (![[controllerManager player1] extendedGamepad] || wantsStartSelectInMenu)
		{
			// left trigger bound to Start
			// right trigger bound to Select
			[actionsheet addAction:[UIAlertAction actionWithTitle:@"P1 Start" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
				[weakSelf.emulatorCore setPauseEmulation:NO];
				weakSelf.isShowingMenu = NO;
				[weakSelf.controllerViewController pressStartForPlayer:0];
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					[weakSelf.controllerViewController releaseStartForPlayer:0];
				});
                
                [weakSelf enableContorllerInput:NO];

			}]];
			[actionsheet addAction:[UIAlertAction actionWithTitle:@"P1 Select" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
				[weakSelf.emulatorCore setPauseEmulation:NO];
				weakSelf.isShowingMenu = NO;
				[weakSelf.controllerViewController pressSelectForPlayer:0];
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					[weakSelf.controllerViewController releaseSelectForPlayer:0];
				});
                
                [weakSelf enableContorllerInput:NO];
                
			}]];

			[actionsheet addAction:[UIAlertAction actionWithTitle:@"P1 AnalogMode" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
				[weakSelf.emulatorCore setPauseEmulation:NO];
				weakSelf.isShowingMenu = NO;
				[weakSelf.controllerViewController pressAnalogModeForPlayer:0];
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					[weakSelf.controllerViewController releaseAnalogModeForPlayer:0];
				});
                
                [weakSelf enableContorllerInput:NO];
                
			}]];
		}
	}
	
	if ([controllerManager player2]) {
		if (![[controllerManager player2] extendedGamepad] || wantsStartSelectInMenu)
		{
			[actionsheet addAction:[UIAlertAction actionWithTitle:@"P2 Start" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
				[weakSelf.emulatorCore setPauseEmulation:NO];
				weakSelf.isShowingMenu = NO;
				[weakSelf.controllerViewController pressStartForPlayer:1];
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					[weakSelf.controllerViewController releaseStartForPlayer:1];
				});
                
                [weakSelf enableContorllerInput:NO];
                
			}]];
			[actionsheet addAction:[UIAlertAction actionWithTitle:@"P2 Select" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
				[weakSelf.emulatorCore setPauseEmulation:NO];
				weakSelf.isShowingMenu = NO;
				[weakSelf.controllerViewController pressSelectForPlayer:1];
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					[weakSelf.controllerViewController releaseSelectForPlayer:1];
				});
                
                [weakSelf enableContorllerInput:NO];
                
			}]];

			[actionsheet addAction:[UIAlertAction actionWithTitle:@"P2 AnalogMode" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
				[weakSelf.emulatorCore setPauseEmulation:NO];
				weakSelf.isShowingMenu = NO;
				[weakSelf.controllerViewController pressAnalogModeForPlayer:1];
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					[weakSelf.controllerViewController releaseAnalogModeForPlayer:1];
				});
                
                [weakSelf enableContorllerInput:NO];
                
			}]];
		}
	}

    if ([self.emulatorCore conformsToProtocol:@protocol(DiscSwappable)])
    {
        [actionsheet addAction:[UIAlertAction actionWithTitle:@"Swap Disc" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf performSelector:@selector(showSwapDiscsMenu)
                           withObject:nil
                           afterDelay:0.1];
        }]];
    }
    
#if !TARGET_OS_TV
    [actionsheet addAction:[UIAlertAction actionWithTitle:@"Screenshot" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf performSelector:@selector(takeScreenshot)
                       withObject:nil
                       afterDelay:0.1];
    }]];
#endif
    
    [actionsheet addAction:[UIAlertAction actionWithTitle:@"Save State" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf performSelector:@selector(showSaveStateMenu)
                       withObject:nil
                       afterDelay:0.1];
    }]];
    
	[actionsheet addAction:[UIAlertAction actionWithTitle:@"Load State" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
		[weakSelf performSelector:@selector(showLoadStateMenu)
					   withObject:nil
					   afterDelay:0.1];
	}]];
    
    [actionsheet addAction:[UIAlertAction actionWithTitle:@"Game Speed" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
		[weakSelf performSelector:@selector(showSpeedMenu)
					   withObject:nil
					   afterDelay:0.1];
    }]];
    
	[actionsheet addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
		if ([[PVSettingsModel sharedInstance] autoSave])
		{
			[weakSelf.emulatorCore autoSaveState];
		}
		
		[weakSelf.emulatorCore setPauseEmulation:NO];
		[weakSelf.emulatorCore resetEmulation];
		weakSelf.isShowingMenu = NO;
        
        [weakSelf enableContorllerInput:NO];
        
	}]];
    
    [actionsheet addAction:[UIAlertAction actionWithTitle:@"Game Info" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Provenance" bundle:nil];
        PVGameMoreInfoViewController * moreInfoViewContrller = (PVGameMoreInfoViewController *)[sb instantiateViewControllerWithIdentifier:@"gameMoreInfoVC"];
        moreInfoViewContrller.game = weakSelf.game;
        moreInfoViewContrller.showsPlayButton = NO;
        moreInfoViewContrller.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(hideModeInfo)];
        UINavigationController *newNav = [[UINavigationController alloc] initWithRootViewController:moreInfoViewContrller];
        
        [weakSelf presentViewController:newNav animated:YES completion:nil];
    }]];
    
	[actionsheet addAction:[UIAlertAction actionWithTitle:@"Return to Game Library" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf quit];
	}]];
    
    UIAlertAction *resumeAction = [UIAlertAction actionWithTitle:@"Resume" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf.emulatorCore setPauseEmulation:NO];
        weakSelf.isShowingMenu = NO;
        
        [weakSelf enableContorllerInput:NO];
        
    }];
    
    [actionsheet addAction:resumeAction];
    
    if (@available(iOS 9.0, *)) {
        actionsheet.preferredAction = resumeAction;
    }
 
    [self presentViewController:actionsheet animated:YES completion:^{
        [[[PVControllerManager sharedManager] iCadeController] refreshListener];
    }];
    
    [self updatePlayedDuration];
}

- (void)hideModeInfo {
    [self dismissViewControllerAnimated:YES completion:^{
#if TARGET_OS_TV
        [self showMenu:nil];
#else
        [self  hideMenu];
#endif
    }];
}


- (void)hideMenu
{
    [self enableContorllerInput:NO];
    
    if (self.menuActionSheet)
    {
        [self dismissViewControllerAnimated:YES completion:NULL];
        self.isShowingMenu = NO;
    }
    
    [self updateLastPlayedTime];
    [self.emulatorCore setPauseEmulation:NO];
}

- (void)updateFPSLabel
{
#if DEBUG
    NSLog(@"FPS: %li", _glViewController.framesPerSecond);
#endif
    self.fpsLabel.text = [NSString stringWithFormat:@"%2.02f", self.emulatorCore.emulationFPS];
}

- (void)showSaveStateMenu
{
	__block PVEmulatorViewController *weakSelf = self;
	
	NSString *saveStatePath = [self saveStatePath];
	NSString *infoPath = [saveStatePath stringByAppendingPathComponent:@"info.plist"];
	
	NSMutableArray *info = [NSMutableArray arrayWithContentsOfFile:infoPath];
	if (!info)
	{
		info = [NSMutableArray array];
        [info addObjectsFromArray:@[@"Slot 1 (empty)",
                                    @"Slot 2 (empty)",
                                    @"Slot 3 (empty)",
                                    @"Slot 4 (empty)",
                                    @"Slot 5 (empty)"]];
	}
	
    UIAlertController *actionsheet = [UIAlertController alertControllerWithTitle:nil
                                                                         message:nil
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    if (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        [[actionsheet popoverPresentationController] setSourceView:self.menuButton];
        [[actionsheet popoverPresentationController] setSourceRect:[self.menuButton bounds]];
    }
    self.menuActionSheet = actionsheet;
	
	for (NSUInteger i = 0; i < 5; i++)
	{
		[actionsheet addAction:[UIAlertAction actionWithTitle:info[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
			NSDate *now = [NSDate date];
			NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
			[formatter setDateStyle:NSDateFormatterShortStyle];
			[formatter setTimeStyle:NSDateFormatterShortStyle];
			
			info[i] = [NSString stringWithFormat:@"Slot %tu (%@)", i+1, [formatter stringFromDate:now]];
			[info writeToFile:infoPath atomically:YES];
			
			NSString *savePath = [saveStatePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%tu.svs", i]];
			
			[weakSelf.emulatorCore saveStateToFileAtPath:savePath];
			[weakSelf.emulatorCore setPauseEmulation:NO];
			weakSelf.isShowingMenu = NO;
            
            [weakSelf enableContorllerInput:NO];
            
		}]];
	}
	
	[actionsheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
		[weakSelf.emulatorCore setPauseEmulation:NO];
		weakSelf.isShowingMenu = NO;
        
        [weakSelf enableContorllerInput:NO];
        
	}]];

    [self presentViewController:actionsheet animated:YES completion:^{
        [[[PVControllerManager sharedManager] iCadeController] refreshListener];
    }];
}

- (void)showLoadStateMenu
{
	__block PVEmulatorViewController *weakSelf = self;
	
	NSString *saveStatePath = [self saveStatePath];
	NSString *infoPath = [saveStatePath stringByAppendingPathComponent:@"info.plist"];
	NSString *autoSavePath = [saveStatePath stringByAppendingPathComponent:@"auto.svs"];
	
	NSMutableArray *info = [NSMutableArray arrayWithContentsOfFile:infoPath];
	if (!info)
	{
        info = [NSMutableArray array];
        [info addObjectsFromArray:@[@"Slot 1 (empty)",
                                    @"Slot 2 (empty)",
                                    @"Slot 3 (empty)",
                                    @"Slot 4 (empty)",
                                    @"Slot 5 (empty)"]];
	}
	
	UIAlertController *actionsheet = [UIAlertController alertControllerWithTitle:nil
                                                                         message:nil
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    if (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        [[actionsheet popoverPresentationController] setSourceView:self.menuButton];
        [[actionsheet popoverPresentationController] setSourceRect:[self.menuButton bounds]];
    }
    self.menuActionSheet = actionsheet;
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:autoSavePath])
	{
		[actionsheet addAction:[UIAlertAction actionWithTitle:@"Last AutoSave" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
			[weakSelf.emulatorCore loadStateFromFileAtPath:autoSavePath];
			[weakSelf.emulatorCore setPauseEmulation:NO];
			weakSelf.isShowingMenu = NO;
            
            [weakSelf enableContorllerInput:NO];
            
		}]];
	}
	
	for (NSUInteger i = 0; i < 5; i++)
	{
		[actionsheet addAction:[UIAlertAction actionWithTitle:info[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
			NSString *savePath = [saveStatePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%tu.svs", i]];
			if ([[NSFileManager defaultManager] fileExistsAtPath:savePath])
			{
				[weakSelf.emulatorCore loadStateFromFileAtPath:savePath];
			}
			[weakSelf.emulatorCore setPauseEmulation:NO];
			weakSelf.isShowingMenu = NO;
            
            [weakSelf enableContorllerInput:NO];
            
		}]];
	}
	
	[actionsheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
		[weakSelf.emulatorCore setPauseEmulation:NO];
		weakSelf.isShowingMenu = NO;
        
        [weakSelf enableContorllerInput:NO];
        
	}]];

     [self presentViewController:actionsheet animated:YES completion:^{
         [[[PVControllerManager sharedManager] iCadeController] refreshListener];
     }];
}

#if !TARGET_OS_TV
- (void)takeScreenshot
{
    [UIView animateWithDuration:0.4 animations:^{
        _fpsLabel.alpha = 0;
    } completion:^(BOOL finished) {
        if (finished) {
            CGFloat width = _glViewController.view.frame.size.width;
            CGFloat height = _glViewController.view.frame.size.height;
            
            CGSize size = CGSizeMake(width, height);
            
            UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
            
            CGRect rec = CGRectMake(0, 0, width, height);
            [_glViewController.view drawViewHierarchyInRect:rec afterScreenUpdates:YES];
            
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
            });
            
            [self.emulatorCore setPauseEmulation:NO];
            self.isShowingMenu = NO;
            
            [UIView animateWithDuration:0.4 animations:^{
                _fpsLabel.alpha = 1;
            }];
        }
    }];
}
#endif

- (void)showSpeedMenu
{
    __block PVEmulatorViewController *weakSelf = self;
    
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"Game Speed"
                                                                         message:nil
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    
    if (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        [[actionSheet popoverPresentationController] setSourceView:self.menuButton];
        [[actionSheet popoverPresentationController] setSourceRect:[self.menuButton bounds]];
    }
    
    NSArray<NSString *> *speeds = @[@"Slow", @"Normal", @"Fast"];
    [speeds enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		[actionSheet addAction:[UIAlertAction actionWithTitle:obj style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
			weakSelf.emulatorCore.gameSpeed = idx;
			[weakSelf.emulatorCore setPauseEmulation:NO];
			weakSelf.isShowingMenu = NO;
            
            [weakSelf enableContorllerInput:NO];
            
		}]];
	}];
	
	[self presentViewController:actionSheet animated:YES completion:^{
		[[[PVControllerManager sharedManager] iCadeController] refreshListener];
	}];
}

- (void)quit
{
    [self quit:NULL];
}

- (void)quit:(void(^)(void))completion
{
    if ([[PVSettingsModel sharedInstance] autoSave])
    {
        [self.emulatorCore autoSaveState];
    }

    [self.emulatorCore stopEmulation]; //Leave emulation loop first

	[self.fpsTimer invalidate];
	self.fpsTimer = nil;
    [self.gameAudio stopAudio];
#if !TARGET_OS_TV
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
#endif
    [self dismissViewControllerAnimated:YES completion:completion];
    
    [self enableContorllerInput:NO];
    
    [self updatePlayedDuration];
}

#pragma mark - Controllers

//#if TARGET_OS_TV
// Ensure that override of menu gesture is caught and handled properly for tvOS
-(void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(nullable UIPressesEvent *)event {
    
    UIPress *press = (UIPress *)presses.anyObject;
    if ( press && press.type == UIPressTypeMenu && !self.isShowingMenu )
    {
//         [self controllerPauseButtonPressed];
    }
    else
    {
        [super pressesBegan:presses withEvent:event];
    }
}
//#endif

- (void)controllerPauseButtonPressed:(id)sender
{
	dispatch_async(dispatch_get_main_queue(), ^{
		if (![self isShowingMenu])
		{
			[self showMenu:self];
		}
		else
		{
			[self hideMenu];
		}
	});
}

- (void)controllerDidConnect:(NSNotification *)note
{
#if !TARGET_OS_SIMULATOR
    GCController *controller = [note object];
    // 8Bitdo controllers don't have a pause button, so don't hide the menu
    if (![controller isKindOfClass:[PViCade8BitdoController class]]) {
        [self.menuButton setHidden:YES];

    // In instances where the controller is connected *after* the VC has been shown, we need to set the pause handler
#if !TARGET_OS_TV
        __weak PVEmulatorViewController *weakSelf = self;
        [controller setControllerPausedHandler:^(GCController * _Nonnull controller) {
            [weakSelf controllerPauseButtonPressed:weakSelf];
        }];
		if (@available(iOS 11.0, *))
		{
			[self setNeedsUpdateOfHomeIndicatorAutoHidden];
		}
#endif
    }
#endif
}

- (void)controllerDidDisconnect:(NSNotification *)note
{
	[self.menuButton setHidden:NO];
#if !TARGET_OS_TV
	if (@available(iOS 11.0, *))
	{
		[self setNeedsUpdateOfHomeIndicatorAutoHidden];
	}
#endif
}

- (void)handleControllerManagerControllerReassigned:(NSNotification *)notification
{
	self.emulatorCore.controller1 = [[PVControllerManager sharedManager] player1];
	self.emulatorCore.controller2 = [[PVControllerManager sharedManager] player2];
}

#pragma mark - UIScreenNotifications

- (void)screenDidConnect:(NSNotification *)note
{
    NSLog(@"Screen did connect: %@", [note object]);
    if (!self.secondaryScreen)
    {
        self.secondaryScreen = [[UIScreen screens] objectAtIndex:1];
        self.secondaryWindow = [[UIWindow alloc] initWithFrame:[self.secondaryScreen bounds]];
        [self.secondaryWindow setScreen:self.secondaryScreen];
        [[self.glViewController view] removeFromSuperview];
        [self.glViewController removeFromParentViewController];
        [self.secondaryWindow setRootViewController:self.glViewController];
        [[self.glViewController view] setFrame:[self.secondaryWindow bounds]];
        [self.secondaryWindow addSubview:[self.glViewController view]];
        [self.secondaryWindow setHidden:NO];
        [[self.glViewController view] setNeedsLayout];
    }
}

- (void)screenDidDisconnect:(NSNotification *)note
{
    NSLog(@"Screen did disconnect: %@", [note object]);
    UIScreen *screen = [note object];
    if (self.secondaryScreen == screen)
    {
        [[self.glViewController view] removeFromSuperview];
        [self.glViewController removeFromParentViewController];
        [self addChildViewController:self.glViewController];
        [self.view insertSubview:[self.glViewController view] belowSubview:[self.controllerViewController view]];
        [[self.glViewController view] setNeedsLayout];
        self.secondaryWindow = nil;
        self.secondaryScreen = nil;
    }
}

#pragma mark - PVAudioDelegate

- (void)audioSampleRateDidChange
{
    [self.gameAudio stopAudio];
    [self.gameAudio startAudio];
}

@end
