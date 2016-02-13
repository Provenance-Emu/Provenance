//
//  PVEmulatorViewController.m
//  Provenance
//
//  Created by James Addyman on 14/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVEmulatorViewController.h"
#import "PVGLViewController.h"
#import "PVEmulatorCore.h"
#import "PVGame.h"
#import "OEGameAudio.h"
#import "JSButton.h"
#import "JSDPad.h"
#import "UIActionSheet+BlockAdditions.h"
#import "UIAlertView+BlockAdditions.h"
#import "PVButtonGroupOverlayView.h"
#import "PVSettingsModel.h"
#import "UIView+FrameAdditions.h"
#import <QuartzCore/QuartzCore.h>
#import "PVEmulatorConfiguration.h"
#import "PVControllerManager.h"

@interface PVEmulatorViewController ()

@property (nonatomic, strong) PVGLViewController *glViewController;
@property (nonatomic, strong) OEGameAudio *gameAudio;
@property (nonatomic, strong) PVControllerViewController *controllerViewController;

@property (nonatomic, strong) UIButton *menuButton;

@property (nonatomic, weak) UIAlertController *menuActionSheet;
@property (nonatomic, assign) BOOL isShowingMenu;

@property (nonatomic, strong) UIScreen *secondaryScreen;
@property (nonatomic, strong) UIWindow *secondaryWindow;


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
    [self.emulatorCore stopEmulation];
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
	
	self.emulatorCore = nil;
	self.gameAudio = nil;
	self.glViewController = nil;
	self.controllerViewController = nil;
	self.menuButton = nil;

    for (GCController *controller in [GCController controllers])
    {
        [controller setControllerPausedHandler:nil];
    }
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

	self.emulatorCore = [[PVEmulatorConfiguration sharedInstance] emulatorCoreForSystemIdentifier:[self.game systemIdentifier]];
    [self.emulatorCore setSaveStatesPath:[self saveStatePath]];
	[self.emulatorCore setBatterySavesPath:[self batterySavesPath]];
    [self.emulatorCore setBIOSPath:self.BIOSPath];
    [self.emulatorCore setController1:[[PVControllerManager sharedManager] player1]];
    [self.emulatorCore setController2:[[PVControllerManager sharedManager] player2]];
	
	self.glViewController = [[PVGLViewController alloc] initWithEmulatorCore:self.emulatorCore];

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

	self.controllerViewController = [[PVEmulatorConfiguration sharedInstance] controllerViewControllerForSystemIdentifier:[self.game systemIdentifier]];
	[self.controllerViewController setEmulatorCore:self.emulatorCore];
	[self addChildViewController:self.controllerViewController];
	[self.view addSubview:[self.controllerViewController view]];
	[self.controllerViewController didMoveToParentViewController:self];
	
	CGFloat alpha = [[PVSettingsModel sharedInstance] controllerOpacity];
	self.menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[self.menuButton setFrame:CGRectMake(([[self view] bounds].size.width - 62) / 2, 10, 62, 22)];
	[self.menuButton setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin| UIViewAutoresizingFlexibleBottomMargin];
	[self.menuButton setBackgroundImage:[UIImage imageNamed:@"button-thin"] forState:UIControlStateNormal];
	[self.menuButton setBackgroundImage:[UIImage imageNamed:@"button-thin-pressed"] forState:UIControlStateHighlighted];
	[self.menuButton setTitle:@"Menu" forState:UIControlStateNormal];
	[[self.menuButton titleLabel] setShadowOffset:CGSizeMake(0, 1)];
	[self.menuButton setTitleShadowColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
	[[self.menuButton titleLabel] setFont:[UIFont boldSystemFontOfSize:15]];
	[self.menuButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[self.menuButton setAlpha:alpha];
	[self.menuButton addTarget:self action:@selector(showMenu:) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:self.menuButton];
	
	if ([[GCController controllers] count])
	{
		[self.menuButton setHidden:YES];
	}

    if (![self.emulatorCore loadFileAtPath:[[self documentsPath] stringByAppendingPathComponent:[self.game romPath]]])
    {
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
			[self presentViewController:alert animated:YES completion:NULL];
		}
	}

    __weak PVEmulatorViewController *weakSelf = self;
    for (GCController *controller in [GCController controllers])
    {
        [controller setControllerPausedHandler:^(GCController * _Nonnull controller) {
            [weakSelf controllerPauseButtonPressed];
        }];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

#if !TARGET_OS_TV
	[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
#endif
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

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}


- (void)appWillEnterForeground:(NSNotification *)note
{
	if (!self.isShowingMenu)
	{
		[self.emulatorCore setPauseEmulation:NO];
        [self.gameAudio startAudio];
	}
}

- (void)appDidEnterBackground:(NSNotification *)note
{
    [self.emulatorCore autoSaveState];
	[self.emulatorCore setPauseEmulation:YES];
    [self.gameAudio pauseAudio];
}

- (void)appWillResignActive:(NSNotification *)note
{
    [self.emulatorCore autoSaveState];
	[self.emulatorCore setPauseEmulation:YES];
    [self.gameAudio pauseAudio];
}

- (void)appDidBecomeActive:(NSNotification *)note
{
	if (!self.isShowingMenu)
	{
		[self.emulatorCore setShouldResyncTime:YES];
		[self.emulatorCore setPauseEmulation:NO];
        [self.gameAudio startAudio];
	}
}

- (void)showMenu:(id)sender
{
#if TARGET_OS_TV
    self.controllerUserInteractionEnabled = YES;
#endif

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
#if TARGET_OS_TV
            self.controllerUserInteractionEnabled = NO;
#endif
		}]];
    }

#if TARGET_OS_TV
    PVControllerManager *controllerManager = [PVControllerManager sharedManager];
    if (![[controllerManager player1] extendedGamepad])
    {
        // left trigger bound to Start
        // right trigger bound to Select
        [actionsheet addAction:[UIAlertAction actionWithTitle:@"P1 Start" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf.emulatorCore setPauseEmulation:NO];
            weakSelf.isShowingMenu = NO;
            [weakSelf.controllerViewController pressStartForPlayer:0];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf.controllerViewController releaseStartForPlayer:0];
            });
#if TARGET_OS_TV
            weakSelf.controllerUserInteractionEnabled = NO;
#endif
        }]];
        [actionsheet addAction:[UIAlertAction actionWithTitle:@"P1 Select" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf.emulatorCore setPauseEmulation:NO];
            weakSelf.isShowingMenu = NO;
            [weakSelf.controllerViewController pressSelectForPlayer:0];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf.controllerViewController releaseSelectForPlayer:0];
            });
#if TARGET_OS_TV
            weakSelf.controllerUserInteractionEnabled = NO;
#endif
        }]];
    }
    if (![[controllerManager player2] extendedGamepad])
    {
        [actionsheet addAction:[UIAlertAction actionWithTitle:@"P2 Start" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf.emulatorCore setPauseEmulation:NO];
            weakSelf.isShowingMenu = NO;
            [weakSelf.controllerViewController pressStartForPlayer:1];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf.controllerViewController releaseStartForPlayer:1];
            });
#if TARGET_OS_TV
            weakSelf.controllerUserInteractionEnabled = NO;
#endif
        }]];
        [actionsheet addAction:[UIAlertAction actionWithTitle:@"P2 Select" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [weakSelf.emulatorCore setPauseEmulation:NO];
            weakSelf.isShowingMenu = NO;
            [weakSelf.controllerViewController pressSelectForPlayer:1];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf.controllerViewController releaseSelectForPlayer:1];
            });
#if TARGET_OS_TV
            weakSelf.controllerUserInteractionEnabled = NO;
#endif
        }]];
    }
#endif

    if ([self.emulatorCore supportsDiskSwapping])
    {
        [actionsheet addAction:[UIAlertAction actionWithTitle:@"Swap Disk" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[weakSelf emulatorCore] swapDisk];
        }]];
    }

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
    [actionsheet addAction:[UIAlertAction actionWithTitle:@"Toggle Fast Forward" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf.emulatorCore setFastForward:!weakSelf.emulatorCore.fastForward];
        [weakSelf.emulatorCore setPauseEmulation:NO];
        weakSelf.isShowingMenu = NO;
#if TARGET_OS_TV
        weakSelf.controllerUserInteractionEnabled = NO;
#endif
    }]];
	[actionsheet addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
		if ([[PVSettingsModel sharedInstance] autoSave])
		{
			[weakSelf.emulatorCore autoSaveState];
		}
		
		[weakSelf.emulatorCore setPauseEmulation:NO];
		[weakSelf.emulatorCore resetEmulation];
		weakSelf.isShowingMenu = NO;

#if TARGET_OS_TV
        weakSelf.controllerUserInteractionEnabled = NO;
#endif
	}]];
	[actionsheet addAction:[UIAlertAction actionWithTitle:@"Return to Game Library" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [weakSelf quit];
	}]];
	[actionsheet addAction:[UIAlertAction actionWithTitle:@"Resume" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
		[weakSelf.emulatorCore setPauseEmulation:NO];
		weakSelf.isShowingMenu = NO;
#if TARGET_OS_TV
        weakSelf.controllerUserInteractionEnabled = NO;
#endif
	}]];

    [self presentViewController:actionsheet animated:YES completion:^{
        [[[PVControllerManager sharedManager] iCadeController] refreshListener];
    }];
}

- (void)hideMenu
{
#if TARGET_OS_TV
    self.controllerUserInteractionEnabled = NO;
#endif

    if (self.menuActionSheet)
    {
        [self dismissViewControllerAnimated:YES completion:NULL];
        [self.emulatorCore setPauseEmulation:NO];
        self.isShowingMenu = NO;
    }
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
#if TARGET_OS_TV
            self.controllerUserInteractionEnabled = NO;
#endif
		}]];
	}
	
	[actionsheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
		[weakSelf.emulatorCore setPauseEmulation:NO];
		weakSelf.isShowingMenu = NO;
#if TARGET_OS_TV
        self.controllerUserInteractionEnabled = NO;
#endif
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
#if TARGET_OS_TV
            self.controllerUserInteractionEnabled = NO;
#endif
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
#if TARGET_OS_TV
            self.controllerUserInteractionEnabled = NO;
#endif
		}]];
	}
	
	[actionsheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
		[weakSelf.emulatorCore setPauseEmulation:NO];
		weakSelf.isShowingMenu = NO;
#if TARGET_OS_TV
        self.controllerUserInteractionEnabled = NO;
#endif
	}]];

     [self presentViewController:actionsheet animated:YES completion:^{
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

    [self.gameAudio stopAudio];
    [self.emulatorCore stopEmulation];
#if !TARGET_OS_TV
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
#endif
    [self dismissViewControllerAnimated:YES completion:completion];
#if TARGET_OS_TV
    self.controllerUserInteractionEnabled = NO;
#endif
}

#pragma mark - Controllers

- (void)controllerPauseButtonPressed
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
	[self.menuButton setHidden:YES];
}

- (void)controllerDidDisconnect:(NSNotification *)note
{
	[self.menuButton setHidden:NO];
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

@end
