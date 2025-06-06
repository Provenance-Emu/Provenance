//  PVEmuThreeCoreBridge.m
//  Copyright © 2023 Provenance. All rights reserved.

#import "PVEmuThreeCoreBridge+Controls.h"
//#import "PVEmuThreeCoreBridge+Audio.h"
//#import "PVEmuThreeCoreBridge+Video.h"
#import <PVEmuThree/PVEmuThree-Swift.h>

#import <Foundation/Foundation.h>
@import PVCoreBridge;
@import PVLoggingObjC;
#import <PVCoreObjCBridge/PVCoreObjCBridge.h>

/* Citra Includes */
#import <PVEmuThree/CitraWrapper.h>
#include "core/savestate.h"
#include "core/hle/service/am/am.h"

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4
#define IS_IPHONE() ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)

__weak PVEmuThreeCoreBridge *_current = 0;
bool _isInitialized;
static bool _isOff = false;

@interface PVEmuThreeCoreBridge() {
}

@end

#pragma mark - PVEmuThreeCoreBridge Begin

@implementation PVEmuThreeCoreBridge
{
    uint16_t *_soundBuffer;
    float _frameInterval;
    NSString *autoLoadStatefileName;
    NSString *_emuThreeCoreModule;
    CGSize _emuThreeCoreAspect;
    CGSize _emuThreeCoreScreen;
    NSString *_romPath;
}

- (instancetype)init {
    if (self = [super init]) {
        self.alwaysUseMetal = true;
        self.skipLayout = true;
        _current=self;
        _videoWidth  = 640;
        _videoHeight = 480;
        _videoBitDepth = 32; // ignored
        dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);
        _callbackQueue = dispatch_queue_create("org.provenance-emu.emuThree.CallbackHandlerQueue", queueAttributes);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(optionUpdated:) name:@"OptionUpdated" object:nil];
        _isInitialized = false;
        [self parseOptions];
    }
    return self;
}

- (void)dealloc {
    _current = nil;
}

#pragma mark - PVEmulatorCore
- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
    NSBundle *coreBundle = [NSBundle bundleForClass:[self class]];
    const char *dataPath;
    [self initControllBuffers];
    NSString *configPath = self.saveStatesPath;
    dataPath = [[coreBundle resourcePath] fileSystemRepresentation];
    [[NSFileManager defaultManager] createDirectoryAtPath:configPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    NSString *batterySavesDirectory = self.batterySavesPath;
    [[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    _romPath = [path copy];
    _emuThreeCoreModule = @"3DS";
    _frameInterval = 120;
    _emuThreeCoreAspect = CGSizeMake(16,9);
    _emuThreeCoreScreen = CGSizeMake(640, 480);
    _videoWidth = 640;
    _videoHeight = 480;
    _isInitialized = false;
    
    [self parseOptions];
    
    if ([path.pathExtension.lowercaseString isEqualToString:@"nds"]) {
        _emuThreeCoreModule = @"NDS";
    } else if ([path.pathExtension.lowercaseString isEqualToString:@"cia"]) {
        Service::AM::InstallStatus success = Service::AM::InstallCIA([path UTF8String], [](std::size_t total_bytes_read, std::size_t file_size) {});
//        return success == Service::AM::InstallStatus::Success;
    }

    return YES;
}

- (void)setOptionValues {
#warning("TODO: I don't think these Keys are correct.")
    // TODO: I don't think this is correct and should either use a custom default domain or needs
    // to prepend something to the key names to match what CoreOption's encoder does
    [self parseOptions];
    [[NSUserDefaults standardUserDefaults] setInteger:self.portraitType forKey:@"portrait_layout_option"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.landscapeType forKey:@"landscape_layout_option"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.resFactor forKey:@"resolution_factor"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.cpuOClock forKey:@"cpu_clock_percentage"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.stereoRender forKey:@"render_3d"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.threedFactor forKey:@"factor_3d"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.volume forKey:@"audio_volume"];

    [[NSUserDefaults standardUserDefaults] setInteger:self.shaderType forKey:@"shader_type"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.region forKey:@"region_value"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.language forKey:@"language_value"];

    [[NSUserDefaults standardUserDefaults] setBool:self.asyncShader  forKey:@"async_shader_compilation"];
    [[NSUserDefaults standardUserDefaults] setBool:self.asyncPresent forKey:@"async_presentation"];
    [[NSUserDefaults standardUserDefaults] setBool:(self.shaderType >= 2) forKey:@"use_hw_shader"];

    [[NSUserDefaults standardUserDefaults] setBool:self.stretchAudio forKey:@"stretch_audio"];
    [[NSUserDefaults standardUserDefaults] setBool:self.realtimeAudio forKey:@"use_realtime_audio"];
    [[NSUserDefaults standardUserDefaults] setBool:self.enableJIT forKey:@"use_cpu_jit"];
    [[NSUserDefaults standardUserDefaults] setBool:self.enableLogging forKey:@"enable_logging"];
    [[NSUserDefaults standardUserDefaults] setBool:self.useNew3DS forKey:@"is_new_3ds"];
    [[NSUserDefaults standardUserDefaults] setBool:self.enableVSync forKey:@"use_vsync_new"];
    [[NSUserDefaults standardUserDefaults] setBool:self.enableShaderAccurate forKey:@"shaders_accurate_mul"];
    [[NSUserDefaults standardUserDefaults] setBool:self.enableShaderJIT forKey:@"use_shader_jit"];
    [[NSUserDefaults standardUserDefaults] setBool:self.swapScreen forKey:@"swap_screen"];
    [[NSUserDefaults standardUserDefaults] setBool:self.uprightScreen forKey:@"upright_screen"];
    [[NSUserDefaults standardUserDefaults] setBool:self.customTextures forKey:@"custom_textures"];
    [[NSUserDefaults standardUserDefaults] setBool:self.preloadTextures forKey:@"preload_textures"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Running
- (void)setupEmulation {
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString* saveDirectory = [self.batterySavesPath stringByAppendingPathComponent:@"../EmuThreeData" ];
}

- (void)startVM:(UIView *)view {
    DLOG(@"Starting VM\n");
    m_view=view;
    [self startEmuThree];
}

- (void)startEmuThree {
    _isInitialized = false;
    [CitraWrapper.sharedInstance useMetalLayer:(CAMetalLayer *)m_view.layer];
    [CitraWrapper.sharedInstance load:_romPath];
    [self setupControllers];
    DLOG(@"VM Started\n");
    [CitraWrapper.sharedInstance run];
    [self refreshScreenSize];
    _isInitialized = true;
    _isOff = false;
}

- (void)startEmulation {
    // Skip Emulation Loop since the core has its own loop
    self.skipEmulationLoop = true;
    if (!Core::InitMem()) {
        [self stopEmulation];
        return;
    }
    [self setOptionValues];
    [self setupEmulation];
    [self setupView];
    [super startEmulation];
}

- (void)setPauseEmulation:(BOOL)flag {
    [super setPauseEmulation:flag];
    if (flag)
        [CitraWrapper.sharedInstance pauseEmulation];
    else {
        [self setOptionValues];
        [CitraWrapper.sharedInstance resumeEmulation];
    }
}

- (void)resetEmulation {
    [CitraWrapper.sharedInstance resetEmulation];
}

- (void)refreshScreenSize {
    NSLog(@"refreshScreenSize: Window Size %f %f\n", self.touchViewController.view.frame.size.width, self.touchViewController.view.frame.size.height);
#if !TARGET_OS_TV
    if ([[UIDevice currentDevice] orientation] == UIDeviceOrientationPortrait ||
        [[UIDevice currentDevice] orientation] == UIDeviceOrientationPortraitUpsideDown) {
        if (m_view.frame.size.width > m_view.frame.size.height) {
            m_view.frame =  CGRectMake(0, 0, m_view.frame.size.height, m_view.frame.size.width);
        }
    } else {
#endif
        if (m_view.frame.size.width < m_view.frame.size.height) {
            m_view.frame =  CGRectMake(0, 0, m_view.frame.size.height, m_view.frame.size.width);
        }
#if !TARGET_OS_TV
    }
#endif
    [CitraWrapper.sharedInstance refreshSize:m_view.layer];
}

- (void)stopEmulation {
    [CitraWrapper.sharedInstance shutdownEmulation];
    [super stopEmulation];
    self.shouldStop = YES;
    _isInitialized = false;
    _isOff=true;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[[[UIApplication sharedApplication] delegate] window] makeKeyAndVisible];
}

- (void)setupView {
    if (self.touchViewController) {
        UIViewController *gl_view_controller = (UIViewController *)self.renderDelegate;
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        m_view_controller=[[EmuThreeVulkanViewController alloc]
                           initWithResFactor:self.resFactor
                           videoWidth: self.videoWidth
                           videoHeight: self.videoHeight
                           core: self];
        m_view=m_view_controller.view;
        UIViewController *rootController = m_view_controller;
        [self.touchViewController.view addSubview:m_view];
        [self.touchViewController addChildViewController:rootController];
        [rootController didMoveToParentViewController:self.touchViewController];
        [self.touchViewController.view sendSubviewToBack:m_view];
        [rootController.view setHidden:false];
        if (IS_IPHONE()) {
            rootController.view.translatesAutoresizingMaskIntoConstraints = true;
            rootController.view.insetsLayoutMarginsFromSafeArea = true;
        } else {
            rootController.view.translatesAutoresizingMaskIntoConstraints = false;
            [[rootController.view.safeAreaLayoutGuide.topAnchor constraintEqualToAnchor:self.touchViewController.view.safeAreaLayoutGuide.topAnchor] setActive:YES];
            [[rootController.view.safeAreaLayoutGuide.bottomAnchor constraintEqualToAnchor:self.touchViewController.view.safeAreaLayoutGuide.bottomAnchor] setActive:YES];
            [[rootController.view.safeAreaLayoutGuide.leadingAnchor constraintEqualToAnchor:self.touchViewController.view.safeAreaLayoutGuide.leadingAnchor] setActive:YES];
            [[rootController.view.safeAreaLayoutGuide.trailingAnchor constraintEqualToAnchor:self.touchViewController.view.safeAreaLayoutGuide.trailingAnchor] setActive:YES];
        }
        self.touchViewController.view.autoresizesSubviews=true;
        self.touchViewController.view.userInteractionEnabled=true;
#if !TARGET_OS_TV
        self.touchViewController.view.multipleTouchEnabled=true;
#endif
    } else {
        UIViewController *gl_view_controller = (UIViewController *)self.renderDelegate;
        auto screenBounds = [[UIScreen mainScreen] bounds];
        if(self.gsPreference == 0)
        {
            EmuThreeVulkanViewController *cgsh_view_controller=[[EmuThreeVulkanViewController alloc]
                                                                initWithResFactor:self.resFactor
                                                                videoWidth: self.videoWidth
                                                                videoHeight: self.videoHeight
                                                                core: self];
            m_metal_layer=(CAMetalLayer *)cgsh_view_controller.view.layer;
            m_view_controller=(UIViewController *)cgsh_view_controller;
            m_view=cgsh_view_controller.view;
            m_view.contentMode = UIViewContentModeScaleToFill;
            [gl_view_controller addChildViewController:cgsh_view_controller];
            [cgsh_view_controller didMoveToParentViewController:gl_view_controller];
        } else if(self.gsPreference == 1) {
            EmuThreeOGLViewController *cgsh_view_controller=[[EmuThreeOGLViewController alloc]
                                                             initWithResFactor:self.resFactor
                                                             videoWidth: self.videoWidth
                                                             videoHeight: self.videoHeight
                                                             core: self];
            m_gl_layer=(CAEAGLLayer *)cgsh_view_controller.view.layer;
            m_view_controller=(UIViewController *)cgsh_view_controller;
            m_view=cgsh_view_controller.view;
            m_view.contentMode = UIViewContentModeScaleToFill;
            [gl_view_controller addChildViewController:cgsh_view_controller];
            [cgsh_view_controller didMoveToParentViewController:gl_view_controller];
        }
        if ([gl_view_controller respondsToSelector:@selector(mtlView)]) {
            MTKView* mtlView = self.renderDelegate.mtlView;
            NSAssert(mtlView, @"mtlView was nil");
            mtlView.autoresizesSubviews=true;
            mtlView.clipsToBounds=true;
            [mtlView addSubview:m_view];
            [m_view.safeAreaLayoutGuide.widthAnchor constraintGreaterThanOrEqualToAnchor:mtlView.safeAreaLayoutGuide.widthAnchor].active=true;
            [m_view.safeAreaLayoutGuide.heightAnchor constraintGreaterThanOrEqualToAnchor:mtlView.safeAreaLayoutGuide.heightAnchor constant: 0].active=true;
            [m_view.safeAreaLayoutGuide.topAnchor constraintEqualToAnchor:mtlView.safeAreaLayoutGuide.topAnchor constant:0].active = true;
            [m_view.safeAreaLayoutGuide.leadingAnchor constraintEqualToAnchor:mtlView.safeAreaLayoutGuide.leadingAnchor constant:0].active = true;
            [m_view.safeAreaLayoutGuide.trailingAnchor constraintEqualToAnchor:mtlView.safeAreaLayoutGuide.trailingAnchor constant:0].active = true;
            [m_view.safeAreaLayoutGuide.bottomAnchor constraintEqualToAnchor:mtlView.safeAreaLayoutGuide.bottomAnchor constant:0].active = true;
        } else {
            UIView* glView = gl_view_controller.view;
            NSAssert(glView, @"glView was nil");
            glView.autoresizesSubviews=true;
            glView.clipsToBounds=true;
            [glView addSubview:m_view];
            [m_view.safeAreaLayoutGuide.widthAnchor constraintGreaterThanOrEqualToAnchor:glView.safeAreaLayoutGuide.widthAnchor].active=true;
            [m_view.safeAreaLayoutGuide.heightAnchor constraintGreaterThanOrEqualToAnchor:glView.safeAreaLayoutGuide.heightAnchor constant: 0].active=true;
            [m_view.safeAreaLayoutGuide.topAnchor constraintEqualToAnchor:glView.safeAreaLayoutGuide.topAnchor constant:0].active = true;
            [m_view.safeAreaLayoutGuide.leadingAnchor constraintEqualToAnchor:glView.safeAreaLayoutGuide.leadingAnchor constant:0].active = true;
            [m_view.safeAreaLayoutGuide.trailingAnchor constraintEqualToAnchor:glView.safeAreaLayoutGuide.trailingAnchor constant:0].active = true;
            [m_view.safeAreaLayoutGuide.bottomAnchor constraintEqualToAnchor:glView.safeAreaLayoutGuide.bottomAnchor constant:0].active = true;
        }
    }
}

-(void)startHaptic { }
-(void)stopHaptic { }

-(void)optionUpdated:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    for (NSString* key in info.allKeys) {
        NSString *value=[info valueForKey:key];
        [self processOption:key value:value];
        printf("Received Option key:%s value:%s\n",key.UTF8String, value.UTF8String);
    }
}

-(void)processOption:(NSString *)key value:(NSString*)value {
    typedef void (^Process)();
    NSDictionary *actions = @{
        @"Swap Screen":
        ^{
            self.swapScreen = [value isEqualToString:@"true"];
            [CitraWrapper.sharedInstance swap:self.swapScreen];
        },
        @"Upright Screen":
        ^{
            self.uprightScreen = [value isEqualToString:@"true"];
            [CitraWrapper.sharedInstance rotate:self.uprightScreen];
        },
        @"Portrait Layout":
        ^{
            self.portraitType = [value integerValue];
            [CitraWrapper.sharedInstance layout:self.portraitType];
        },
        
        @"Shader Acceleration / Graphic Accuracy":
        ^{
            [self setOptionValues];
            [CitraWrapper.sharedInstance setShaderOption];
            [CitraWrapper.sharedInstance resetController];
        },
        @"Landscape Layout":
        ^{
            self.landscapeType= [value integerValue];
            [CitraWrapper.sharedInstance layout:self.landscapeType];
        },
        @"3D Stereo Render":
        ^{
            [self setOptionValues];
            [CitraWrapper.sharedInstance setOptions:false];
            [CitraWrapper.sharedInstance resetController];
        },
        @"3D Factor":
        ^{
            [self setOptionValues];
            [CitraWrapper.sharedInstance setOptions:false];
            [CitraWrapper.sharedInstance resetController];
        },
        @"Stretch Audio":
        ^{
            [self setOptionValues];
            [CitraWrapper.sharedInstance setOptions:false];
            [CitraWrapper.sharedInstance resetController];
        },
        @"Audio Volume":
        ^{
            [self setOptionValues];
            [CitraWrapper.sharedInstance setOptions:false];
            [CitraWrapper.sharedInstance resetController];
        },
        @"Enable Async Presentation":
        ^{
            [self setOptionValues];
            [CitraWrapper.sharedInstance setOptions:false];
            [CitraWrapper.sharedInstance resetController];
        },
        @"System Language":
        ^{
            [self setOptionValues];
            [CitraWrapper.sharedInstance setOptions:false];
            [CitraWrapper.sharedInstance resetController];
        },
    };
    Process action=[actions objectForKey:key];
    if (action) {
        action();
    } else {
        [self setOptionValues];
        [CitraWrapper.sharedInstance setOptions:false];
    }
}
@end
