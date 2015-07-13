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

@interface PVEmulatorViewController ()

@property (nonatomic, strong) PVGLViewController *glViewController;
@property (nonatomic, strong) OEGameAudio *gameAudio;
@property (nonatomic, strong) PVControllerViewController *controllerViewController;

@property (nonatomic, strong) UIButton *menuButton;

@property (nonatomic, strong) UIPanGestureRecognizer *dPadPanRecognizer;
@property (nonatomic, strong) UIPanGestureRecognizer *buttonPanRecognizer;
@property (nonatomic, strong) UIButton *saveControlsButton;
@property (nonatomic, strong) UIButton *resetControlsButton;

@property (nonatomic, weak) UIActionSheet *menuActionSheet;
@property (nonatomic, assign) BOOL isShowingMenu;

@end

static __unsafe_unretained PVEmulatorViewController *_staticEmulatorViewController;

@implementation PVEmulatorViewController

void uncaughtExceptionHandler(NSException *exception)
{
	NSString *saveStatePath = [_staticEmulatorViewController saveStatePath];
	NSString *autoSavePath = [saveStatePath stringByAppendingPathComponent:@"auto.svs"];
	[_staticEmulatorViewController.emulatorCore saveStateToFileAtPath:autoSavePath];
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
	
	self.emulatorCore = [[PVEmulatorConfiguration sharedInstance] emulatorCoreForSystemIdentifier:[self.game systemIdentifier]];
	[self.emulatorCore setBatterySavesPath:[self batterySavesPath]];
    [self.emulatorCore setBIOSPath:self.BIOSPath];
    if (![self.emulatorCore loadFileAtPath:[[self documentsPath] stringByAppendingPathComponent:[self.game romPath]]])
    {
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            DLog(@"Unable to load ROM at %@", [self.game romPath]);
            [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
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
	[self.gameAudio setVolume:1.0];
	[self.gameAudio setOutputDeviceID:0];
	[self.gameAudio startAudio];
	
	self.glViewController = [[PVGLViewController alloc] initWithEmulatorCore:self.emulatorCore];
	[self addChildViewController:self.glViewController];
	[self.view addSubview:[self.glViewController view]];
	[self.glViewController didMoveToParentViewController:self];
	
	self.controllerViewController = [[PVEmulatorConfiguration sharedInstance] controllerViewControllerForSystemIdentifier:[self.game systemIdentifier]];
	[self.controllerViewController setEmulatorCore:self.emulatorCore];
	[self.controllerViewController setDelegate:self];
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
			
			UIAlertView *alert = [[UIAlertView alloc] init];
			[alert setTitle:@"Autosave file detected"];
			[alert setMessage:@"Would you like to load it?"];\
			[alert addButtonWithTitle:@"Yes"];
			[alert addButtonWithTitle:@"Yes, and stop asking"];
			[alert addButtonWithTitle:@"No"];
			[alert addButtonWithTitle:@"No, and stop asking"];
			[alert PV_setCompletionHandler:^(NSUInteger buttonIndex) {
				if (buttonIndex == 0)
				{
					[weakSelf.emulatorCore loadStateFromFileAtPath:autoSavePath];
					[weakSelf.emulatorCore setPauseEmulation:NO];
				}
				else if (buttonIndex == 1)
				{
					[weakSelf.emulatorCore loadStateFromFileAtPath:autoSavePath];
					[[PVSettingsModel sharedInstance] setAutoSave:YES];
					[[PVSettingsModel sharedInstance] setAskToAutoLoad:NO];
				}
				else if (buttonIndex == 2)
				{
					[weakSelf.emulatorCore setPauseEmulation:NO];
				}
				else if (buttonIndex == 3)
				{
					[weakSelf.emulatorCore setPauseEmulation:NO];
					[[PVSettingsModel sharedInstance] setAskToAutoLoad:NO];
					[[PVSettingsModel sharedInstance] setAutoLoadAutoSaves:NO];
				}
			}];
			[alert show];
		}
	}
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
}

- (NSString *)documentsPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    
    return documentsDirectoryPath;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

//- (NSUInteger)supportedInterfaceOrientations
//{
//	return UIInterfaceOrientationMaskLandscape;
//}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationLandscapeLeft;
}


- (void)appWillEnterForeground:(NSNotification *)note
{
	if (!self.isShowingMenu)
	{
		[self.emulatorCore setPauseEmulation:NO];
	}
}

- (void)appDidEnterBackground:(NSNotification *)note
{
	[self.emulatorCore setPauseEmulation:YES];
}

- (void)appWillResignActive:(NSNotification *)note
{
	[self.emulatorCore setPauseEmulation:YES];
}

- (void)appDidBecomeActive:(NSNotification *)note
{
	if (!self.isShowingMenu)
	{
		[self.emulatorCore setShouldResyncTime:YES];
		[self.emulatorCore setPauseEmulation:NO];
	}
}

- (void)showMenu:(id)sender
{
	__block PVEmulatorViewController *weakSelf = self;
	
	[self.emulatorCore setPauseEmulation:YES];
	self.isShowingMenu = YES;
	
    UIActionSheet *actionsheet = [[UIActionSheet alloc] init];
    self.menuActionSheet = actionsheet;
    
	[actionsheet setActionSheetStyle:UIActionSheetStyleBlackTranslucent];
	
	if (![self.controllerViewController gameController])
	{
		[actionsheet PV_addButtonWithTitle:@"Edit Controls" action:^{
			[weakSelf.controllerViewController editControls];
		}];
	}
	
	[actionsheet PV_addButtonWithTitle:@"Save State" action:^{
		[weakSelf performSelector:@selector(showSaveStateMenu)
					   withObject:nil
					   afterDelay:0.1];
	}];
	[actionsheet PV_addButtonWithTitle:@"Load State" action:^{
		[weakSelf performSelector:@selector(showLoadStateMenu)
					   withObject:nil
					   afterDelay:0.1];
	}];
	[actionsheet PV_addButtonWithTitle:@"Reset" action:^{
		if ([[PVSettingsModel sharedInstance] autoSave])
		{
			NSString *saveStatePath = [self saveStatePath];
			NSString *autoSavePath = [saveStatePath stringByAppendingPathComponent:@"auto.svs"];
			[weakSelf.emulatorCore saveStateToFileAtPath:autoSavePath];
		}
		
		[weakSelf.emulatorCore setPauseEmulation:NO];
		[weakSelf.emulatorCore resetEmulation];
		weakSelf.isShowingMenu = NO;
	}];
	[actionsheet PV_addButtonWithTitle:@"Quit" action:^{
		if ([[PVSettingsModel sharedInstance] autoSave])
		{
			NSString *saveStatePath = [weakSelf saveStatePath];
			NSString *autoSavePath = [saveStatePath stringByAppendingPathComponent:@"auto.svs"];
			[weakSelf.emulatorCore saveStateToFileAtPath:autoSavePath];
		}
		
		[weakSelf.gameAudio stopAudio];
		[weakSelf.emulatorCore stopEmulation];
		[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
		[weakSelf dismissViewControllerAnimated:YES completion:NULL];
	}];
	[actionsheet PV_addCancelButtonWithTitle:@"Resume" action:^{
		[weakSelf.emulatorCore setPauseEmulation:NO];
		weakSelf.isShowingMenu = NO;
	}];
	[actionsheet showInView:self.view];
}

- (void)hideMenu
{
    if (self.menuActionSheet)
    {
        [self.menuActionSheet dismissWithClickedButtonIndex:[self.menuActionSheet cancelButtonIndex] animated:YES];
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
	
	UIActionSheet *actionsheet = [[UIActionSheet alloc] init];
    self.menuActionSheet = actionsheet;
	[actionsheet setActionSheetStyle:UIActionSheetStyleBlackTranslucent];
	
	for (NSUInteger i = 0; i < 5; i++)
	{
		[actionsheet PV_addButtonWithTitle:info[i] action:^{
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
		}];
	}
	
	[actionsheet PV_addCancelButtonWithTitle:@"Cancel" action:^{
		[weakSelf.emulatorCore setPauseEmulation:NO];
		weakSelf.isShowingMenu = NO;
	}];
	
	[actionsheet showInView:self.view];
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
	
	UIActionSheet *actionsheet = [[UIActionSheet alloc] init];
    self.menuActionSheet = actionsheet;
	[actionsheet setActionSheetStyle:UIActionSheetStyleBlackTranslucent];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:autoSavePath])
	{
		[actionsheet PV_addButtonWithTitle:@"Last Autosave" action:^{
			[weakSelf.emulatorCore loadStateFromFileAtPath:autoSavePath];
			[weakSelf.emulatorCore setPauseEmulation:NO];
			weakSelf.isShowingMenu = NO;
		}];
	}
	
	for (NSUInteger i = 0; i < 5; i++)
	{
		[actionsheet PV_addButtonWithTitle:info[i] action:^{
			NSString *savePath = [saveStatePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%tu.svs", i]];
			if ([[NSFileManager defaultManager] fileExistsAtPath:savePath])
			{
				[weakSelf.emulatorCore loadStateFromFileAtPath:savePath];
			}
			[weakSelf.emulatorCore setPauseEmulation:NO];
			weakSelf.isShowingMenu = NO;
		}];
	}
	
	[actionsheet PV_addCancelButtonWithTitle:@"Cancel" action:^{
		[weakSelf.emulatorCore setPauseEmulation:NO];
		weakSelf.isShowingMenu = NO;
	}];
	
	[actionsheet showInView:self.view];
}

#pragma mark - PVControllerViewControllerDelegate

- (void)controllerViewControllerDidPressMenuButton:(PVControllerViewController *)controllerViewController
{
	if (![self isShowingMenu])
	{
		[self showMenu:self];
	}
    else
    {
        [self hideMenu];
    }
}

- (void)controllerViewControllerDidBeginEditing:(PVControllerViewController *)controllerViewController
{
	[self.menuButton setEnabled:NO];
}

- (void)controllerViewControllerDidEndEditing:(PVControllerViewController *)controllerViewController
{
	[self.menuButton setEnabled:YES];
	[self.emulatorCore setPauseEmulation:NO];
	self.isShowingMenu = NO;
}

- (void)controllerDidConnect:(NSNotification *)note
{
	[self.menuButton setHidden:YES];
}

- (void)controllerDidDisconnect:(NSNotification *)note
{
	[self.menuButton setHidden:NO];
}

@end
