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
#import "UIAlertView+BlockAdditions.h"
#import "PVButtonGroupOverlayView.h"
#import "PVSettingsModel.h"

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

static __unsafe_unretained PVEmulatorViewController *_staticEmulatorViewController;

@implementation PVEmulatorViewController

void uncaughtExceptionHandler(NSException *exception)
{
	NSString *saveStatePath = [_staticEmulatorViewController saveStatePath];
	NSString *autoSavePath = [saveStatePath stringByAppendingPathComponent:@"auto.svs"];
	[_staticEmulatorViewController.genesisCore saveStateToFileAtPath:autoSavePath];
}

+ (void)initialize
{
	if ([[PVSettingsModel sharedInstance] autoSave])
	{
		NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
	}
}

- (instancetype)initWithROMPath:(NSString *)path
{
	if ((self = [super init]))
	{
		_staticEmulatorViewController = self;
		self.romPath = path;
	}
	
	return self;
}

- (void)dealloc
{
	NSSetUncaughtExceptionHandler(NULL);
	_staticEmulatorViewController = nil;
	
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
	
	[self.view setBackgroundColor:[UIColor blackColor]];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(appDidBecomeActive:)
												 name:UIApplicationDidBecomeActiveNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(appWillResignActive:)
												 name:UIApplicationWillResignActiveNotification
											   object:nil];
	
	self.genesisCore = [[PVGenesisEmulatorCore alloc] init];
	[self.genesisCore setBatterySavesPath:[self batterySavesPath]];
	
	[self.genesisCore loadFileAtPath:self.romPath];
	
	self.gameAudio = [[OEGameAudio alloc] initWithCore:self.genesisCore];
	[self.gameAudio setVolume:1.0];
	[self.gameAudio setOutputDeviceID:0];
	[self.gameAudio startAudio];
	
	self.glViewController = [[PVGLViewController alloc] initWithGenesisCore:self.genesisCore];
	[[self.glViewController view] setFrame:CGRectMake([self.view bounds].size.width - 320, 0, 320, 224)];
	[[self.glViewController view] setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin];
	
	[self.view addSubview:[self.glViewController view]];
	
	[self.genesisCore startEmulation];
	
	CGFloat alpha = [[PVSettingsModel sharedInstance] controllerOpacity];
	
	self.dPad = [[JSDPad alloc] initWithFrame:CGRectMake(5, [[self view] bounds].size.height - 185, 180, 180)];
	[self.dPad setAutoresizingMask:UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin];
	[self.dPad setDelegate:self];
	[self.dPad setAlpha:alpha];
	[self.view addSubview:self.dPad];
	
	UIView *buttonContainer = [[UIView alloc] initWithFrame:CGRectMake(([self.view bounds].size.width - 212) - 5, ([self.view bounds].size.height - 92) - 5, 212, 92)];
	[buttonContainer setAutoresizingMask:UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin];
	[self.view addSubview:buttonContainer];
	
	self.aButton = [[JSButton alloc] initWithFrame:CGRectMake(8, 24, 60, 60)];
	[[self.aButton titleLabel] setText:@"A"];
	[self.aButton setBackgroundImage:[UIImage imageNamed:@"button"]];
	[self.aButton setBackgroundImagePressed:[UIImage imageNamed:@"button-pressed"]];
	[self.aButton setDelegate:self];
	[self.aButton setAlpha:alpha];
	[buttonContainer addSubview:self.aButton];
	
	self.bButton = [[JSButton alloc] initWithFrame:CGRectMake(76, 16, 60, 60)];
	[[self.bButton titleLabel] setText:@"B"];
	[self.bButton setBackgroundImage:[UIImage imageNamed:@"button"]];
	[self.bButton setBackgroundImagePressed:[UIImage imageNamed:@"button-pressed"]];
	[self.bButton setDelegate:self];
	[self.bButton setAlpha:alpha];
	[buttonContainer addSubview:self.bButton];
	
	self.cButton = [[JSButton alloc] initWithFrame:CGRectMake(144, 8, 60, 60)];
	[[self.cButton titleLabel] setText:@"C"];
	[self.cButton setBackgroundImage:[UIImage imageNamed:@"button"]];
	[self.cButton setBackgroundImagePressed:[UIImage imageNamed:@"button-pressed"]];
	[self.cButton setDelegate:self];
	[self.cButton setAlpha:alpha];
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
	[self.startButton setAlpha:alpha];
	[self.view addSubview:self.startButton];
	
	self.menuButton = [[JSButton alloc] initWithFrame:CGRectMake(([[self view] bounds].size.width - 62) / 2, [self.glViewController view].bounds.size.height + 10, 62, 22)];
	[self.menuButton setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin];
	[self.menuButton setBackgroundImage:[UIImage imageNamed:@"button-thin"]];
	[self.menuButton setBackgroundImagePressed:[UIImage imageNamed:@"button-thin-pressed"]];
	[[self.menuButton titleLabel] setText:@"Menu"];
	[[self.menuButton titleLabel] setFont:[UIFont boldSystemFontOfSize:12]];
	[self.menuButton setTitleEdgeInsets:UIEdgeInsetsMake(0, 0, 4, 0)];
	[self.menuButton setDelegate:self];
	[self.menuButton setAlpha:alpha];
	[self.view addSubview:self.menuButton];
	
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
	{
		[[self.glViewController view] setFrame:CGRectMake(([self.view bounds].size.width - 472) / 2, 0, 457, 320)];
		[self.menuButton setFrame:CGRectMake(([[self view] bounds].size.width - 62) / 2, 10, 62, 22)];
		[self.menuButton setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin];
	}
	
	NSString *saveStatePath = [_staticEmulatorViewController saveStatePath];
	NSString *autoSavePath = [saveStatePath stringByAppendingPathComponent:@"auto.svs"];
	if ([[NSFileManager defaultManager] fileExistsAtPath:autoSavePath])
	{
		BOOL shouldAskToLoadSaveState = [[PVSettingsModel sharedInstance] askToAutoLoad];
		BOOL shouldAutoLoadSaveState = [[PVSettingsModel sharedInstance] autoLoadAutoSaves];
		
		__weak PVEmulatorViewController *weakSelf = self;
		
		if (shouldAutoLoadSaveState)
		{
			[weakSelf.genesisCore loadStateFromFileAtPath:autoSavePath];
		}
		else if (shouldAskToLoadSaveState)
		{
			[self.genesisCore setPauseEmulation:YES];
			
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
					[weakSelf.genesisCore loadStateFromFileAtPath:autoSavePath];
					[weakSelf.genesisCore setPauseEmulation:NO];
				}
				else if (buttonIndex == 1)
				{
					[weakSelf.genesisCore loadStateFromFileAtPath:autoSavePath];
					[[PVSettingsModel sharedInstance] setAutoSave:YES];
					[[PVSettingsModel sharedInstance] setAskToAutoLoad:NO];
				}
				else if (buttonIndex == 2)
				{
					[weakSelf.genesisCore setPauseEmulation:NO];
				}
				else if (buttonIndex == 3)
				{
					[weakSelf.genesisCore setPauseEmulation:NO];
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
	
	[actionsheet PV_addButtonWithTitle:@"Save State" action:^{
		dispatch_sync(dispatch_get_main_queue(), ^{
			[weakSelf performSelector:@selector(showSaveStateMenu)
						   withObject:nil
						   afterDelay:0.1];
		});
	}];
	[actionsheet PV_addButtonWithTitle:@"Load State" action:^{
		dispatch_sync(dispatch_get_main_queue(), ^{
			[weakSelf performSelector:@selector(showLoadStateMenu)
						   withObject:nil
						   afterDelay:0.1];
		});
	}];
	[actionsheet PV_addButtonWithTitle:@"Reset" action:^{
		dispatch_sync(dispatch_get_main_queue(), ^{
			if ([[PVSettingsModel sharedInstance] autoSave])
			{
				NSString *saveStatePath = [self saveStatePath];
				NSString *autoSavePath = [saveStatePath stringByAppendingPathComponent:@"auto.svs"];
				[self.genesisCore saveStateToFileAtPath:autoSavePath];
			}
			
			[weakSelf.genesisCore setPauseEmulation:NO];
			[weakSelf.genesisCore resetEmulation];
		});
	}];
	[actionsheet PV_addButtonWithTitle:@"Quit" action:^{
		dispatch_sync(dispatch_get_main_queue(), ^{
			if ([[PVSettingsModel sharedInstance] autoSave])
			{
				NSString *saveStatePath = [self saveStatePath];
				NSString *autoSavePath = [saveStatePath stringByAppendingPathComponent:@"auto.svs"];
				[self.genesisCore saveStateToFileAtPath:autoSavePath];
			}
			
			[weakSelf.gameAudio stopAudio];
			[weakSelf.genesisCore stopEmulation];
			[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
			[weakSelf dismissViewControllerAnimated:YES completion:NULL];
		});
	}];
	[actionsheet PV_addCancelButtonWithTitle:@"Resume" action:^{
		dispatch_sync(dispatch_get_main_queue(), ^{
			[weakSelf.genesisCore setPauseEmulation:NO];
		});
	}];
	[actionsheet showInView:self.view];
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
	
	for (NSUInteger i = 0; i < 5; i++)
	{
		[actionsheet PV_addButtonWithTitle:info[i] action:^{
			dispatch_sync(dispatch_get_main_queue(), ^{
				NSDate *now = [NSDate date];
				NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
				[formatter setDateStyle:NSDateFormatterShortStyle];
				[formatter setTimeStyle:NSDateFormatterShortStyle];
				
				info[i] = [NSString stringWithFormat:@"Slot %u (%@)", i+1, [formatter stringFromDate:now]];
				[info writeToFile:infoPath atomically:YES];
				
				NSString *savePath = [saveStatePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%u.svs", i]];
				
				[weakSelf.genesisCore saveStateToFileAtPath:savePath];
				[weakSelf.genesisCore setPauseEmulation:NO];
			});
		}];
	}
	
	[actionsheet PV_addCancelButtonWithTitle:@"Cancel" action:^{
		dispatch_sync(dispatch_get_main_queue(), ^{
			[weakSelf.genesisCore setPauseEmulation:NO];
		});
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
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:autoSavePath])
	{
		[actionsheet PV_addButtonWithTitle:@"Last Autosave" action:^{
			dispatch_sync(dispatch_get_main_queue(), ^{
				[self.genesisCore loadStateFromFileAtPath:autoSavePath];
				[weakSelf.genesisCore setPauseEmulation:NO];
			});
		}];
	}
	
	for (NSUInteger i = 0; i < 5; i++)
	{
		[actionsheet PV_addButtonWithTitle:info[i] action:^{
			dispatch_sync(dispatch_get_main_queue(), ^{
				NSString *savePath = [saveStatePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%u.svs", i]];
				if ([[NSFileManager defaultManager] fileExistsAtPath:savePath])
				{
					[self.genesisCore loadStateFromFileAtPath:savePath];
				}
				[weakSelf.genesisCore setPauseEmulation:NO];
			});
		}];
	}
	
	[actionsheet PV_addCancelButtonWithTitle:@"Cancel" action:^{
		dispatch_sync(dispatch_get_main_queue(), ^{
			[weakSelf.genesisCore setPauseEmulation:NO];
		});
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
