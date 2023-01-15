//
//  PVRetroArchCore.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVRetroArchCore.h"
#import "PVRetroArchCore+Controls.h"
#import "PVRetroArchCore+Audio.h"
#import "PVRetroArchCore+Video.h"
#import <PVRetroArch/RetroArch-Swift.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <PVSupport/PVLogging.h>
#import <PVSupport/PVEmulatorCore.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include "./cocoa_common.h"
#include "./apple_platform.h"
#include "./metal_common.h"

/* RetroArch Includes */
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include <boolean.h>

#include <file/file_path.h>
#include <queues/task_queue.h>
#include <string/stdstring.h>
#include <retro_timers.h>
#include "../ui_companion_driver.h"
#include "../../configuration.h"
#include "../../frontend/frontend.h"
#include "../../input/drivers/cocoa_input.h"
#include "../../retroarch.h"
#include "../../verbosity.h"
#include "../../paths.h"

#ifdef HAVE_MENU
#include "../../menu/menu_setting.h"
#endif
#import <AVFoundation/AVFoundation.h>

apple_frontend_settings_t apple_frontend_settings;
extern id<ApplePlatform> apple_platform;
extern void *apple_gamecontroller_joypad_init(void *data);
static void rarch_draw_observer(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info);
void ui_companion_cocoatouch_event_command(void *data, enum event_command cmd);
void handle_touch_event(NSArray* touches);
void frontend_darwin_get_env(int *argc, char *argv[], void *args, void *params_data);
void dir_check_defaults(const char *custom_ini_path);
void bundle_decompressed(retro_task_t *task, void *task_data, void *user_data, const char *err);
void main_msg_queue_push(const char *msg, unsigned prio, unsigned duration, bool flush);
bool processing_init=false;
int g_gs_preference;
extern GLKView *glk_view;
extern CocoaView* g_instance;
UIView *_renderView;
apple_view_type_t _vt;
extern bool _isInitialized;
char **argv;
int argc =  1;

#pragma mark - PVRetroArchCore Begin

@interface PVRetroArchCore (RetroArchUI)
@end

@implementation PVRetroArchCore (RetroArchUI)
- (void)startEmulation {
	@autoreleasepool {
		self.skipEmulationLoop = true;
		[self setupEmulation];
		[self setOptionValues];
		[self startVM:_renderView];
		[super startEmulation];
	};
}

- (void)setPauseEmulation:(BOOL)flag {
	[super setPauseEmulation:flag];
}

- (void)stopEmulation {
	[super stopEmulation];
	self->shouldStop = YES;
	if (iterate_observer) {
		CFRunLoopObserverInvalidate(iterate_observer);
		CFRelease(iterate_observer);
	}
	iterate_observer = NULL;
	rarch_config_init();
	task_queue_init(false, main_msg_queue_push);
	main_exit(NULL);
	_isInitialized = false;
}
- (void)setOptionValues {
	g_gs_preference = self.gsPreference;

}

void extract_bundles();
-(void) writeConfigFile {
	NSFileManager *fm = [[NSFileManager alloc] init];
	NSString *fileName = [NSString stringWithFormat:@"%@/../../RetroArch/config/retroarch.cfg",
						  self.batterySavesPath];
	if (![fm fileExistsAtPath: fileName]) {
		NSString *src = [[NSBundle bundleForClass:[PVRetroArchCore class]] pathForResource:@"retroarch.cfg" ofType:nil];
		[fm copyItemAtPath:src toPath:fileName error:nil];
		processing_init=true;
	}
    fileName = [NSString stringWithFormat:@"%@/../../RetroArch/config/opt.cfg", self.batterySavesPath];
    // Additional Override Settings
    NSString* content = @"video_driver = \"vulkan\"";
    if (self.gsPreference == 0)
        content=@"video_driver = \"metal\"";
    else if (self.gsPreference == 1)
        content=@"video_driver = \"gl\"";
    else if (self.gsPreference == 2)
        content=@"video_driver = \"vulkan\"";
    [content writeToFile:fileName
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];
}
#pragma mark - Running
- (void)setupEmulation {
    self.alwaysUseMetal = true;
    [self parseOptions];
	settings_t *settings = config_get_ptr();
	if (!settings) {
		rarch_config_init();
		config_set_defaults(global_get_ptr());
		frontend_darwin_get_env(argc, argv, NULL, NULL);
		dir_check_defaults(NULL);
		[self writeConfigFile];
	}
	[self syncResources:self.BIOSPath
					 to:[self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch/system" ]];
}

- (void)syncResources:(NSString*)from to:(NSString*)to {
	if (!from)
		return;
	NSLog(@"Syncing %@ to %@", from, to);
	NSError *error;
	NSFileManager *fm = [[NSFileManager alloc] init];
	NSArray* files = [fm contentsOfDirectoryAtPath:from error:&error];
	for (NSString *file in files) {
		NSString *src=  [NSString stringWithFormat:@"%@/%@", from, file];
		NSString *dst = [NSString stringWithFormat:@"%@/%@", to, file];
		if (![fm fileExistsAtPath: dst]) {
			[fm copyItemAtPath:src toPath:dst error:nil];
		}
	}
}
- (void)setViewType:(apple_view_type_t)vt
{
   if (vt == _vt)
      return;

   _vt = vt;
   if (_renderView != nil)
   {
      [_renderView removeFromSuperview];
      _renderView = nil;
   }

   switch (vt)
   {
       case APPLE_VIEW_TYPE_VULKAN: {
                self.gsPreference = 2;
                MetalView *v = [MetalView new];
                v.paused                = YES;
                v.enableSetNeedsDisplay = NO;
                v.multipleTouchEnabled  = YES;
                v.autoresizesSubviews=true;
                v.autoResizeDrawable=true;
                v.contentMode=UIViewContentModeScaleToFill;
                _renderView = v;
           }
           break;
       case APPLE_VIEW_TYPE_METAL: {
                self.gsPreference = 0;
                MetalView *v = [MetalView new];
                v.paused                = YES;
                v.enableSetNeedsDisplay = NO;
                #if TARGET_OS_IOS
                v.multipleTouchEnabled  = YES;
                #endif
                _renderView = v;
        }
        break;
       case APPLE_VIEW_TYPE_OPENGL_ES:
           self.gsPreference = 1;
           glkitview_init();
           _renderView = glk_view;
         break;
       case APPLE_VIEW_TYPE_NONE:
       default:
         return;
   }

   _renderView.translatesAutoresizingMaskIntoConstraints = NO;
   UIView *rootView = [CocoaView get].view;
   [rootView addSubview:_renderView];
   [[_renderView.topAnchor constraintEqualToAnchor:rootView.topAnchor] setActive:YES];
   [[_renderView.bottomAnchor constraintEqualToAnchor:rootView.bottomAnchor] setActive:YES];
   [[_renderView.leadingAnchor constraintEqualToAnchor:rootView.leadingAnchor] setActive:YES];
   [[_renderView.trailingAnchor constraintEqualToAnchor:rootView.trailingAnchor] setActive:YES];
}

- (void)setupView {
    printf("Set:SetupView %d", self.gsPreference);
	if(self.gsPreference == 0) {
		[self setViewType:APPLE_VIEW_TYPE_METAL];
	} else if(self.gsPreference == 1) {
		[self setViewType:APPLE_VIEW_TYPE_OPENGL_ES];
	} else if(self.gsPreference == 2) {
		[self setViewType:APPLE_VIEW_TYPE_VULKAN];
    } else {
        [self setViewType:APPLE_VIEW_TYPE_METAL];
    }
}

- (void)startVM:(UIView *)view {
	apple_platform     = self;
	ELOG(@"Starting VM\n");
	NSString *optConfig = [NSString stringWithFormat:@"%@/../../RetroArch/config/opt.cfg",
						  self.batterySavesPath];
	if(!self.coreIdentifier || [[self coreIdentifier] isEqualToString:@"com.provenance.core.retroarch"] || !romPath) {
		char *param[] = { "retroarch", "--appendconfig", optConfig.UTF8String, NULL };
        argc=3;
		argv=param;
		NSLog(@"Loading %s\n", param[0]);
	} else {
		NSString *sysPath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"modules/%@", [self coreIdentifier]] ofType:nil];
		NSFileManager *fm = [[NSFileManager alloc] init];
		if ([fm fileExistsAtPath: sysPath]) {
			NSLog(@"Found Module %s\n", sysPath.UTF8String);
		}
		if ([fm fileExistsAtPath: romPath]) {
			NSLog(@"Found Game %s\n", romPath.UTF8String);
		}
		// Core Identifier is the dylib file name
		char *param[] = { "retroarch", "-L", [self coreIdentifier].UTF8String, [romPath UTF8String], "--appendconfig", optConfig.UTF8String, "--verbose", NULL };
		argc=7;
		argv=param;
		NSLog(@"Loading %s %s\n", param[2], param[3]);
	}
	NSError *error;
	[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&error];
	[self refreshSystemConfig];
	[self showGameView];
	rarch_main(argc, argv, NULL);
	_isInitialized=true;
	if (processing_init) {
		extract_bundles();
		processing_init=false;
	}
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        runloop_state_t *runloop_st = runloop_state_get_ptr();
        runloop_st->flags &= ~RUNLOOP_FLAG_OVERRIDES_ACTIVE;
    });
	iterate_observer = CFRunLoopObserverCreate(0, kCFRunLoopBeforeWaiting, true, 0, rarch_draw_observer, 0);
	CFRunLoopAddObserver(CFRunLoopGetMain(), iterate_observer, kCFRunLoopCommonModes);
	apple_gamecontroller_joypad_init(NULL);
}

- (void)setupWindow {
    ELOG(@"Set:METAL VULKAN OPENGLES:Attaching View Controller\n");
    if (m_view) {
        [m_view removeFromSuperview];
        m_view=nil;
    }
    if (m_view_controller) {
        [m_view_controller dismissViewControllerAnimated:NO completion:nil];
        m_view_controller=nil;
    }
    if (self.isRootView) {
		self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
		[self.window makeKeyAndVisible];
		CGRect screenBounds = [[UIScreen mainScreen] bounds];
		m_view=[CocoaView get].view;
		self.view=m_view;
		UIWindow *originalWindow=[UIApplication sharedApplication].keyWindow;
		self->backup_view_controller=originalWindow.rootViewController;
		UIViewController *rootController = [CocoaView get];
		[self.window setRootViewController:rootController];
		self.window.userInteractionEnabled=true;
		[rootController.view setHidden:false];
		rootController.view.translatesAutoresizingMaskIntoConstraints = false;
		rootController.view.contentMode = UIViewContentModeScaleToFill;
		[[rootController.view.topAnchor constraintEqualToAnchor:self.window.topAnchor] setActive:YES];
		[[rootController.view.bottomAnchor constraintEqualToAnchor:self.window.bottomAnchor] setActive:YES];
		[[rootController.view.leadingAnchor constraintEqualToAnchor:self.window.leadingAnchor] setActive:YES];
		[[rootController.view.trailingAnchor constraintEqualToAnchor:self.window.trailingAnchor] setActive:YES];
	} else {
        UIViewController *gl_view_controller = self.renderDelegate;
		CGRect screenBounds = [[UIScreen mainScreen] bounds];
		m_view_controller=[CocoaView get];
		m_view=m_view_controller.view;
		self.view=m_view;
		UIViewController *rootController = [CocoaView get];
		[gl_view_controller addChildViewController:rootController];
		[rootController didMoveToParentViewController:gl_view_controller];
		[gl_view_controller.view addSubview:self.view];
		[rootController.view setHidden:false];
		rootController.view.translatesAutoresizingMaskIntoConstraints = false;
		rootController.view.contentMode = UIViewContentModeScaleToFill;
		[[rootController.view.topAnchor constraintEqualToAnchor:gl_view_controller.view.topAnchor] setActive:YES];
		[[rootController.view.bottomAnchor constraintEqualToAnchor:gl_view_controller.view.bottomAnchor] setActive:YES];
		[[rootController.view.leadingAnchor constraintEqualToAnchor:gl_view_controller.view.leadingAnchor] setActive:YES];
		[[rootController.view.trailingAnchor constraintEqualToAnchor:gl_view_controller.view.trailingAnchor] setActive:YES];
	}
}
- (void)showGameView
{
	ELOG(@"In Show Game View now\n");
    [self setupWindow];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		command_event(CMD_EVENT_AUDIO_START, NULL);
	});
}

#pragma mark - ApplePlatform
-(id)renderView { return _renderView; }
-(bool)hasFocus { return YES; }
- (apple_view_type_t)viewType { return _vt; }
- (void)setVideoMode:(gfx_ctx_mode_t)mode
{
#ifdef HAVE_COCOA_METAL
   MetalView *metalView = (MetalView*) _renderView;
   CGFloat scale        = [[UIScreen mainScreen] scale];
   [metalView setDrawableSize:CGSizeMake(
         _renderView.bounds.size.width * scale,
         _renderView.bounds.size.height * scale
         )];
#endif
}
- (void)setCursorVisible:(bool)v { /* no-op for iOS */ }
- (bool)setDisableDisplaySleep:(bool)disable { /* no-op for iOS */ return NO; }
+(PVRetroArchCore *) get { self; }
-(NSString*)documentsDirectory {
	if (self.documentsDirectory == nil) {
#if TARGET_OS_IOS
		NSArray *paths      = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#elif TARGET_OS_TV
		NSArray *paths      = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#endif
		self.documentsDirectory = paths.firstObject;
	}
	return self.documentsDirectory;
}
- (void)refreshSystemConfig {
#if TARGET_OS_IOS
	/* Get enabled orientations */
	apple_frontend_settings.orientation_flags = UIInterfaceOrientationMaskAll;
	if (string_is_equal(apple_frontend_settings.orientations, "landscape"))
		apple_frontend_settings.orientation_flags =
		UIInterfaceOrientationMaskLandscape;
	else if (string_is_equal(apple_frontend_settings.orientations, "portrait"))
		apple_frontend_settings.orientation_flags =
		UIInterfaceOrientationMaskPortrait
		| UIInterfaceOrientationMaskPortraitUpsideDown;
#endif
}
- (void)supportOtherAudioSessions { }
- (void)setupMainWindow { }
/* Delegate */
- (void)applicationDidFinishLaunching:(UIApplication *)application { }
- (void)applicationDidEnterBackground:(UIApplication *)application { }
- (void)applicationWillTerminate:(UIApplication *)application { }
- (void)applicationDidBecomeActive:(UIApplication *)application {
   settings_t *settings            = config_get_ptr();
   bool ui_companion_start_on_boot = settings->bools.ui_companion_start_on_boot;
   if (!ui_companion_start_on_boot)
	  [self showGameView];
}

-(BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
   NSFileManager *manager = [NSFileManager defaultManager];
   NSString     *filename = (NSString*)url.path.lastPathComponent;
   NSError         *error = nil;
   NSString  *destination = [self.documentsDirectory stringByAppendingPathComponent:filename];
   /* Copy file to documents directory if it's not already
	* inside Documents directory */
   if ([url startAccessingSecurityScopedResource]) {
	  if (![[url path] containsString: self.documentsDirectory])
		 if (![manager fileExistsAtPath:destination])
			[manager copyItemAtPath:[url path] toPath:destination error:&error];
	  [url stopAccessingSecurityScopedResource];
   }
   return true;
}

- (void) setRootView:(BOOL)flag {
	if (flag) {
		if (!self.batterySavesPath) {
			NSFileManager *fm = [[NSFileManager alloc] init];
			self.batterySavesPath = [NSString stringWithFormat:@"%@/RetroArch/config",[[fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject].path];
			NSString *fileName = [NSString stringWithFormat:@"%@/../../RetroArch/config/retroarch.cfg",
								  self.batterySavesPath];
			if ([fm fileExistsAtPath: fileName]) {
				//[fm removeItemAtPath:fileName error:nil];
			}
		}
	}
	self.isRootView=flag;
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
   [self refreshSystemConfig];
}

@end

/* RetroArch */
void ui_companion_cocoatouch_event_command(
	  void *data, enum event_command cmd) { }

static void rarch_draw_observer(CFRunLoopObserverRef observer,
	CFRunLoopActivity activity, void *info)
{
   uint32_t runloop_flags;
   int          ret   = runloop_iterate();
   task_queue_check();
   if (ret == -1) {
	   command_event(CMD_EVENT_MENU_SAVE_CURRENT_CONFIG, NULL);
	   ELOG(@"exit loop\n");
	   return;
   }
   runloop_flags = runloop_get_flags();
   if (!(runloop_flags & RUNLOOP_FLAG_IDLE))
	  CFRunLoopWakeUp(CFRunLoopGetMain());
}

void get_ios_version(int *major, int *minor) {
	NSArray *decomposed_os_version = [[UIDevice currentDevice].systemVersion componentsSeparatedByString:@"."];
	if (major && decomposed_os_version.count > 0)
		*major = (int)[decomposed_os_version[0] integerValue];
	if (minor && decomposed_os_version.count > 1)
		*minor = (int)[decomposed_os_version[1] integerValue];
}

void bundle_decompressed(retro_task_t *task,
	  void *task_data,
	  void *user_data, const char *err) {
   decompress_task_data_t *dec = (decompress_task_data_t*)task_data;
   ELOG(@"Bundle Decompressed\n");
   if (err)
	   ELOG(@"%s", err);
   if (dec) {
	  if (!err)
		 command_event(CMD_EVENT_REINIT, NULL);
	  free(dec->source_file);
	  free(dec);
   }
   processing_init=false;
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
       runloop_state_t *runloop_st = runloop_state_get_ptr();
       runloop_st->flags &= ~RUNLOOP_FLAG_OVERRIDES_ACTIVE;
   });
}

void extract_bundles() {
	settings_t *settings = config_get_ptr();
	task_push_decompress(
				settings->paths.bundle_assets_src,
				settings->paths.bundle_assets_dst,
				NULL,
				settings->paths.bundle_assets_dst_subdir,
				NULL,
				bundle_decompressed,
				NULL,
				NULL,
				false);
}
void main_msg_queue_push(const char *msg,
	  unsigned prio, unsigned duration,
	  bool flush)
{
	ELOG(@"MSGQ: %s\n", msg);
}

