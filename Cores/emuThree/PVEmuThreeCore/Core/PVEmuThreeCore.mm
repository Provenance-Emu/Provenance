//  PVEmuThreeCore.m
//  Copyright © 2023 Provenance. All rights reserved.

#import "PVEmuThreeCore.h"
#import "PVEmuThreeCore+Controls.h"
#import "PVEmuThreeCore+Audio.h"
#import "PVEmuThreeCore+Video.h"
#import <PVEmuThree/PVEmuThree-Swift.h>

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

/* Citra Includes */
#import "../emuThree/CitraWrapper.h"
#include "core/savestate.h"

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4
#define IS_IPHONE() ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)

__weak PVEmuThreeCore *_current = 0;
bool _isInitialized;
static bool _isOff = false;

@interface PVEmuThreeCore() {
}

@end

#pragma mark - PVEmuThreeCore Begin

@implementation PVEmuThreeCore
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
        _videoWidth  = 640;
        _videoHeight = 480;
        _videoBitDepth = 32; // ignored
        dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);
        _callbackQueue = dispatch_queue_create("org.provenance-emu.emuThree.CallbackHandlerQueue", queueAttributes);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(optionUpdated:) name:@"OptionUpdated" object:nil];
        _isInitialized = false;
        [self parseOptions];
    }
    _current=self;
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
    return YES;
}

- (void)setOptionValues {
    [self parseOptions];
    [[NSUserDefaults standardUserDefaults] setInteger:self.portraitType forKey:@"portrait_layout_option"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.landscapeType forKey:@"landscape_layout_option"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.resFactor forKey:@"resolution_factor"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.cpuOClock forKey:@"cpu_clock_percentage"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.stereoRender forKey:@"render_3d"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.threedFactor forKey:@"factor_3d"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.volume forKey:@"audio_volume"];

    [[NSUserDefaults standardUserDefaults] setInteger:self.shaderType forKey:@"shader_type"];

    [[NSUserDefaults standardUserDefaults] setBool:self.asyncShader  forKey:@"async_shader_compilation"];
    [[NSUserDefaults standardUserDefaults] setBool:self.asyncPresent forKey:@"async_presentation"];
    [[NSUserDefaults standardUserDefaults] setBool:(self.shaderType >= 2) forKey:@"use_hw_shader"];

    [[NSUserDefaults standardUserDefaults] setBool:self.stretchAudio forKey:@"stretch_audio"];
    [[NSUserDefaults standardUserDefaults] setBool:self.enableJIT forKey:@"use_cpu_jit"];
    [[NSUserDefaults standardUserDefaults] setBool:self.useNew3DS forKey:@"is_new_3ds"];
    [[NSUserDefaults standardUserDefaults] setBool:self.enableVSync forKey:@"use_vsync_new"];
    [[NSUserDefaults standardUserDefaults] setBool:self.enableShaderAccurate forKey:@"shaders_accurate_mul"];
    [[NSUserDefaults standardUserDefaults] setBool:self.enableShaderJIT forKey:@"use_shader_jit"];
    [[NSUserDefaults standardUserDefaults] setBool:self.swapScreen forKey:@"swap_screen"];
    [[NSUserDefaults standardUserDefaults] setBool:self.uprightScreen forKey:@"upright_screen"];
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
    NSLog(@"Starting VM\n");
    m_view=view;
    [self startEmuThree];
}

- (void)startEmuThree {
    _isInitialized = false;
    [CitraWrapper.sharedInstance useMetalLayer:m_view.layer];
    [CitraWrapper.sharedInstance load:_romPath];
    [self setupControllers];
    NSLog(@"VM Started\n");
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
    else
        [CitraWrapper.sharedInstance resumeEmulation];
}

- (void)resetEmulation {
    [CitraWrapper.sharedInstance resetEmulation];
}

- (void)refreshScreenSize {
    NSLog(@"refreshScreenSize: Window Size %f %f\n", self.touchViewController.view.frame.size.width, self.touchViewController.view.frame.size.height);
    if ([[UIDevice currentDevice] orientation] == UIInterfaceOrientationPortrait ||
        [[UIDevice currentDevice] orientation] == UIInterfaceOrientationPortraitUpsideDown) {
        if (m_view.frame.size.width > m_view.frame.size.height) {
            m_view.frame =  CGRectMake(0, 0, m_view.frame.size.height, m_view.frame.size.width);
        }
    } else {
        if (m_view.frame.size.width < m_view.frame.size.height) {
            m_view.frame =  CGRectMake(0, 0, m_view.frame.size.height, m_view.frame.size.width);
        }
    }
    [CitraWrapper.sharedInstance refreshSize:m_view.layer];
}

- (void)stopEmulation {
    [CitraWrapper.sharedInstance shutdownEmulation];
    [super stopEmulation];
    self->shouldStop = YES;
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
        if (IS_IPHONE())
            rootController.view.translatesAutoresizingMaskIntoConstraints = true;
        else {
            rootController.view.translatesAutoresizingMaskIntoConstraints = false;
            [[rootController.view.topAnchor constraintEqualToAnchor:self.touchViewController.view.topAnchor] setActive:YES];
            [[rootController.view.bottomAnchor constraintEqualToAnchor:self.touchViewController.view.bottomAnchor] setActive:YES];
            [[rootController.view.leadingAnchor constraintEqualToAnchor:self.touchViewController.view.leadingAnchor] setActive:YES];
            [[rootController.view.trailingAnchor constraintEqualToAnchor:self.touchViewController.view.trailingAnchor] setActive:YES];
        }
        self.touchViewController.view.autoresizesSubviews=true;
        self.touchViewController.view.userInteractionEnabled=true;
        self.touchViewController.view.multipleTouchEnabled=true;
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
        if ([gl_view_controller respondsToSelector:@selector(mtlview)]) {
            self.renderDelegate.mtlview.autoresizesSubviews=true;
            self.renderDelegate.mtlview.clipsToBounds=true;
            [self.renderDelegate.mtlview addSubview:m_view];
            [m_view.topAnchor constraintEqualToAnchor:self.renderDelegate.mtlview.topAnchor constant:0].active = true;
            [m_view.leadingAnchor constraintEqualToAnchor:self.renderDelegate.mtlview.leadingAnchor constant:0].active = true;
            [m_view.trailingAnchor constraintEqualToAnchor:self.renderDelegate.mtlview.trailingAnchor constant:0].active = true;
            [m_view.bottomAnchor constraintEqualToAnchor:self.renderDelegate.mtlview.bottomAnchor constant:0].active = true;
        } else {
            gl_view_controller.view.autoresizesSubviews=true;
            gl_view_controller.view.clipsToBounds=true;
            [gl_view_controller.view addSubview:m_view];
            [m_view.widthAnchor constraintGreaterThanOrEqualToAnchor:gl_view_controller.view.widthAnchor].active=true;
            [m_view.heightAnchor constraintGreaterThanOrEqualToAnchor:gl_view_controller.view.heightAnchor constant: 0].active=true;
            [m_view.topAnchor constraintEqualToAnchor:gl_view_controller.view.topAnchor constant:0].active = true;
            [m_view.leadingAnchor constraintEqualToAnchor:gl_view_controller.view.leadingAnchor constant:0].active = true;
            [m_view.trailingAnchor constraintEqualToAnchor:gl_view_controller.view.trailingAnchor constant:0].active = true;
            [m_view.bottomAnchor constraintEqualToAnchor:gl_view_controller.view.bottomAnchor constant:0].active = true;
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
    };
    Process action=[actions objectForKey:key];
    if (action)
        action();
}
@end
