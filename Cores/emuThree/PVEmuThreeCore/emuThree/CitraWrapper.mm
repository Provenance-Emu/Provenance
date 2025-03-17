//
//  CitraWrapper.mm
//  emuThreeDS
//
//  Created by Antique on 22/5/2023.
//

// Local Changes: Add Save/Load/Cheat
// Camera interface

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "../emuThree/CitraWrapper.h"
#import "InputFactory.h"
#import <sys/utsname.h>
#import "../emuThree/Camera/CameraFactory.h"
#import "../emuThree/Camera/CameraInterface.h"
#include "../citra_wrapper/helpers/config.h"
#include "file_handle.h"
#include "core/core.h"
#include "core/loader/smdh.h"
#include "emu_window_vk.h"
#include "game_info.h"

#include <future>
#include <algorithm>
#include <chrono>
#include <cryptopp/hex.h>
#include "common/archives.h"
#include "common/logging/log.h"
#include "common/scm_rev.h"
#include "common/zstd_compression.h"
#include "core/movie.h"
#include "core/savestate.h"
#include "network/network.h"

#include "audio_core/dsp_interface.h"
#include "core/cheats/gateway_cheat.h"
#include "core/cheats/cheats.h"
#include "core/cheats/cheat_base.h"
#include "core/core.h"
#include "core/frontend/applets/default_applets.h"
#include "core/hle/service/am/am.h"

#include "common/common_paths.h"
#include "common/logging/backend.h"
#include "common/logging/filter.h"
#include "common/logging/log.h"
#include "core/loader/loader.h"
#include "core/memory.h"
#include "core/hle/service/hid/hid.h"
#include "core/hle/service/apt/applet_manager.h"
#include "video_core/renderer_base.h"
#include "video_core/video_core.h"

#import "InputBridge.h"

#define IS_IPHONE() ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)

Core::System& core{Core::System::GetInstance()};
std::unique_ptr<EmuWindow_VK> emu_window;
@class EmulationInput;

// MARK: Keyboard

namespace SoftwareKeyboard {

class Keyboard final : public Frontend::SoftwareKeyboard {
public:
    ~Keyboard();
    
    void Execute(const Frontend::KeyboardConfig& config) override;
    void ShowError(const std::string& error) override;
    
    void KeyboardText(std::condition_variable& cv);
    std::pair<std::string, uint8_t> GetKeyboardText(const Frontend::KeyboardConfig& config);
    
private:
    __block NSString *_Nullable keyboardText = @"";
    __block uint8_t buttonPressed = 0;
    
    __block BOOL isReady = FALSE;
};

} // namespace SoftwareKeyboard

@implementation KeyboardConfig
-(KeyboardConfig *) initWithHintText:(NSString *)hintText buttonConfig:(KeyboardButtonConfig)buttonConfig {
    if (self = [super init]) {
        self.hintText = hintText;
        self.buttonConfig = buttonConfig;
    } return self;
}
@end

namespace SoftwareKeyboard {

Keyboard::~Keyboard() = default;

void Keyboard::Execute(const Frontend::KeyboardConfig& config) {
    SoftwareKeyboard::Execute(config);
    
    std::pair<std::string, uint8_t> it = this->GetKeyboardText(config);
    if (this->config.button_config != Frontend::ButtonConfig::None)
        it.second = static_cast<uint8_t>(this->config.button_config);
    
    Finalize(it.first, it.second);
}

void Keyboard::ShowError(const std::string& error) {
    printf("error = %s\n", error.c_str());
}

void Keyboard::KeyboardText(std::condition_variable& cv) {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"closeKeyboard" object:NULL queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *notification) {
        this->buttonPressed = (NSUInteger)notification.userInfo[@"buttonPressed"];
        
        NSString *_Nullable text = notification.userInfo[@"keyboardText"];
        if (text != NULL)
            this->keyboardText = text;
        
        isReady = TRUE;
        cv.notify_all();
    }];
}

std::pair<std::string, uint8_t> Keyboard::GetKeyboardText(const Frontend::KeyboardConfig& config) {
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"openKeyboard"
                                                                                         object:[[KeyboardConfig alloc] initWithHintText:[NSString stringWithCString:config.hint_text.c_str() encoding:NSUTF8StringEncoding] buttonConfig:(KeyboardButtonConfig)config.button_config]]];
    
    std::condition_variable cv;
    std::mutex mutex;
    auto t1 = std::async(&Keyboard::KeyboardText, this, std::ref(cv));
    std::unique_lock<std::mutex> lock(mutex);
    while (!isReady)
        cv.wait(lock);
    
    isReady = FALSE;
    
    return std::make_pair([this->keyboardText UTF8String], this->buttonPressed);
}
}

// MARK: Keyboard

static void InitializeLogging() {
#if DEBUG
    Log::Filter log_filter(Log::Level::Trace);
#else
    Log::Filter log_filter(Log::Level::Debug);
#endif
    log_filter.ParseFilterString(Settings::values.log_filter.GetValue());
    Log::SetGlobalFilter(log_filter);
    Log::AddBackend(std::make_unique<Log::ColorConsoleBackend>());
    const std::string& log_dir = FileUtil::GetUserPath(FileUtil::UserPath::LogDir);
    FileUtil::CreateFullPath(log_dir);
    Log::AddBackend(std::make_unique<Log::FileBackend>(log_dir + LOG_FILE));
#ifdef _WIN32
    Log::AddBackend(std::make_unique<Log::DebuggerBackend>());
#endif
}

@implementation CitraWrapper
+(CitraWrapper *) sharedInstance {
    static CitraWrapper *instance = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CitraWrapper alloc] init];
    });

    return instance;
}

-(instancetype) init {
    if (self = [super init]) {
#if DEBUG
        InitializeLogging();
#else
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PVEmuThreeCore.Enable Logging"]) {
            InitializeLogging();
        }
#endif
        finishedShutdown = false;
    } return self;
}

-(uint16_t*) GetIcon:(NSString *)path {
    auto icon = GameInfo::GetIcon(std::string([path UTF8String]));
    return icon.data(); // huh? "Address of stack memory associated with local variable 'icon' returned"
}

-(NSString *) GetPublisher:(NSString *)path {
    auto publisher = GameInfo::GetPublisher(std::string([path UTF8String]));
    return [NSString stringWithCharacters:(const unichar*)publisher.c_str() length:publisher.length()];
}

-(NSString *) GetRegion:(NSString *)path {
    auto regions = GameInfo::GetRegions(std::string([path UTF8String]));
    return [NSString stringWithCString:regions.c_str() encoding:NSUTF8StringEncoding];
}

-(NSString *) GetTitle:(NSString *)path {
    auto title = GameInfo::GetTitle(std::string([path UTF8String]));
    return [NSString stringWithCharacters:(const unichar*)title.c_str() length:title.length()];
}

-(void) useMetalLayer:(CAMetalLayer *)layer {
    _metalLayer = layer;
    emu_window = std::make_unique<EmuWindow_VK>((__bridge CA::MetalLayer*)_metalLayer);
}

-(void) setButtons {
    CitraWrapper.sharedInstance.m_buttonA=[[ButtonInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_buttonB=[[ButtonInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_buttonX=[[ButtonInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_buttonY=[[ButtonInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_buttonL=[[ButtonInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_buttonR=[[ButtonInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_buttonZL=[[ButtonInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_buttonZR=[[ButtonInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_buttonStart=[[ButtonInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_buttonSelect=[[ButtonInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_buttonDpadUp=[[ButtonInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_buttonDpadDown=[[ButtonInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_buttonDpadLeft=[[ButtonInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_buttonDpadRight=[[ButtonInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_buttonDummy=[[ButtonInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_buttonHome=[[ButtonInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_analogCirclePad=[[AnalogInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_analogCirclePad2=[[AnalogInputBridge alloc] init];
    CitraWrapper.sharedInstance.m_motion=[[MotionInputBridge alloc] init];
    for(int i = 0; i < Settings::NativeButton::NumButtons; i++) {
        Common::ParamPackage param{ { "engine", "ios_gamepad" }, { "code", std::to_string(i) } };
        Settings::values.current_input_profile.buttons[i] = param.Serialize();
    }
    for(int i = 0; i < Settings::NativeAnalog::NumAnalogs; i++) {
        Common::ParamPackage param{ { "engine", "ios_gamepad" }, { "code", std::to_string(i) } };
        Settings::values.current_input_profile.analogs[i] = param.Serialize();
    }
    auto frontCamera = std::make_unique<Camera::iOSFrontCameraFactory>();
    auto rearCamera = std::make_unique<Camera::iOSRearCameraFactory>();
    auto rearAltCamera = std::make_unique<Camera::iOSRearAltCameraFactory>();

    Camera::RegisterFactory("av_front", std::move(frontCamera));
    Camera::RegisterFactory("av_rear", std::move(rearCamera));
    Camera::RegisterFactory("av_rear_alt", std::move(rearAltCamera));

    Frontend::RegisterDefaultApplets();
    Input::RegisterFactory<Input::ButtonDevice>("ios_gamepad", std::make_shared<ButtonFactory>());
    Input::RegisterFactory<Input::AnalogDevice>("ios_gamepad", std::make_shared<AnalogFactory>());
    Settings::values.current_input_profile.motion_device="engine:motion_device";
    Input::RegisterFactory<Input::MotionDevice>("motion_emu", std::make_shared<MotionFactory>());

#if defined(TARGET_OS_IPHONE)
    Core::System::GetInstance().RegisterSoftwareKeyboard(std::make_shared<SoftwareKeyboard::Keyboard>());
#endif  x
}

-(void) setShaderOption {
    unsigned int shaderType = [[NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"PVEmuThreeCore.Shader Acceleration / Graphic Accuracy"]] unsignedIntValue];

    Settings::values.use_hw_shader.SetValue(shaderType >= 2);
    Settings::values.shader_type.SetValue(shaderType);
    Settings::Apply();
}

-(void) setOptions:(bool)resetButtons {
    Config{};
    Settings::values.layout_option.SetValue((Settings::LayoutOption)[[NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"PVEmuThreeCore.Portrait Layout"]] unsignedIntValue]);
    Settings::values.resolution_factor.SetValue([[NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"PVEmuThreeCore.Resolution Upscaling"]] unsignedIntValue]);
    Settings::values.async_shader_compilation.SetValue([[NSUserDefaults standardUserDefaults] boolForKey:@"PVEmuThreeCore.Enable Async Shader Compilation"]);
    Settings::values.async_presentation.SetValue([[NSUserDefaults standardUserDefaults] boolForKey:@"PVEmuThreeCore.Enable Async Presentation"]);
    unsigned int shaderType = [[NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"PVEmuThreeCore.Shader Acceleration / Graphic Accuracy"]] unsignedIntValue];
    Settings::values.use_hw_shader.SetValue(shaderType >= 2);
    Settings::values.shader_type.SetValue(shaderType);

    Settings::values.use_cpu_jit.SetValue([[NSUserDefaults standardUserDefaults] boolForKey:@"PVEmuThreeCore.Enable Just in Time"]);
    Settings::values.cpu_clock_percentage.SetValue([[NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"PVEmuThreeCore.CPU Clock Speed"]] unsignedIntValue]);
    Settings::values.is_new_3ds.SetValue([[NSUserDefaults standardUserDefaults] boolForKey:@"PVEmuThreeCore.Enable New 3DS"]);
    

    BOOL enabledLogging = [[NSUserDefaults standardUserDefaults] boolForKey:@"PVEmuThreeCore.Enable Logging"];
    if (enabledLogging) {
#if DEBUG
        Settings::values.log_filter.SetValue("*:Trace");
#else
        Settings::values.log_filter.SetValue("*:Debug");
#endif
    } else {
        Settings::values.log_filter.SetValue("*:Critical");
    }
    
    Settings::values.use_vsync_new.SetValue([[NSUserDefaults standardUserDefaults] boolForKey:@"PVEmuThreeCore.Enable VSync"]);
    Settings::values.shaders_accurate_mul.SetValue([[NSUserDefaults standardUserDefaults] boolForKey:@"PVEmuThreeCore.Enable Shader Accurate Mul"]);
    Settings::values.use_shader_jit.SetValue([[NSUserDefaults standardUserDefaults] boolForKey:@"PVEmuThreeCore.Enable Shader Just in Time"]);

    Settings::values.swap_screen.SetValue([[NSUserDefaults standardUserDefaults] boolForKey:@"PVEmuThreeCore.Swap Screen"]);
    Settings::values.upright_screen.SetValue([[NSUserDefaults standardUserDefaults] boolForKey:@"PVEmuThreeCore.Upright Screen"]);

    Settings::values.render_3d.SetValue((Settings::StereoRenderOption)[[NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"PVEmuThreeCore.3D Stereo Render"]] unsignedIntValue]);
    Settings::values.factor_3d.SetValue([[NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"PVEmuThreeCore.3D Factor"]] unsignedIntValue]);

    Settings::values.dump_textures.SetValue([[NSUserDefaults standardUserDefaults] boolForKey:@"dump_textures"]);
    Settings::values.custom_textures.SetValue([[NSUserDefaults standardUserDefaults] boolForKey:@"PVEmuThreeCore.Use Custom Textures"]);
    Settings::values.preload_textures.SetValue([[NSUserDefaults standardUserDefaults] boolForKey:@"PVEmuThreeCore.Preload Textures"]);
    Settings::values.async_custom_loading.SetValue([[NSUserDefaults standardUserDefaults] boolForKey:@"async_custom_loading"]);

    [self prepareAudio];
    Settings::values.isReloading.SetValue(false);
    
    // Stretch Audio
    shouldStretchAudio=[[NSUserDefaults standardUserDefaults] boolForKey:@"PVEmuThreeCore.Stretch Audio"];
    Settings::values.enable_audio_stretching.SetValue(shouldStretchAudio);
    
    // Volume
    int volume = [[NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"PVEmuThreeCore.Audio Volume"]] unsignedIntValue];
    Settings::values.volume.SetValue((float)volume / 100.0);
    
    // Microphone
    int inputType = [[NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"PVEmuThreeCore.Microphone Input"]] unsignedIntValue];
    Settings::values.input_type.SetValue((AudioCore::InputType) inputType);

    // Region
    int retionType = [[NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"PVEmuThreeCore.System Region"]] intValue];
    Settings::values.region_value.SetValue(retionType);
    
    if (resetButtons)
        [CitraWrapper.sharedInstance setButtons];
    for (const auto& service_module : Service::service_module_map) {
        Settings::values.lle_modules.emplace(service_module.name, ![[NSUserDefaults standardUserDefaults] boolForKey:@"PVEmuThreeCore.Enable High Level Emulation"]);
    }
    
//    Settings::values.lle_applets.SetValue([defaults boolForKey:@"cytrus.lleApplets"]);
    
    [self getModelType];
    Settings::Apply();
}

-(void) getModelType {
    Settings::values.color_attachment.SetValue(false);
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceModel = [[UIDevice currentDevice] model];
    NSString *modelInfo = [NSString stringWithFormat:@"%s", systemInfo.machine];
    NSRange range = [modelInfo rangeOfString:@","];
    NSString *modelName= [modelInfo substringToIndex:range.location];
    NSString *version = [modelName stringByReplacingOccurrencesOfString:deviceModel withString:@""];
    if ([deviceModel containsString:@"iPad"]) {
        if ([version intValue] >= 9) {
            Settings::values.color_attachment.SetValue(true);
        }
    }
    if ([deviceModel containsString:@"iPhone"]) {
        if ([version intValue] >= 12) {
            Settings::values.color_attachment.SetValue(true);
        }
    }
    NSLog(@"Device Model %@ %@", modelName, version);
}

-(void) load:(NSString *)path {
    _path = path;
    [CitraWrapper.sharedInstance setOptions:true];
    FileUtil::SetCurrentRomPath(std::string([_path UTF8String]));
    auto loader = Loader::GetLoader(std::string([_path UTF8String]));
    if(loader)
        loader->ReadProgramId(_title_id);
}

-(void) pauseEmulation {
    CitraWrapper.sharedInstance.isPaused = true;
}

-(void) resumeEmulation {
    CitraWrapper.sharedInstance.isPaused = false;
}

-(void) resetEmulation {
    Settings::values.isReloading.SetValue(true);
    core.SendSignal(Core::System::Signal::Reset);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0* NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        [CitraWrapper.sharedInstance resetController];
    });
}

-(void) asyncResetController {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0* NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        [CitraWrapper.sharedInstance resetController];
    });
}
-(void) shutdownEmulation {
    Settings::values.isReloading.SetValue(true);
    shouldShutdown=true;
    CitraWrapper.sharedInstance.isPaused=false;
    while (CitraWrapper.sharedInstance.isRunning)
        usleep(100);
    usleep(3000);
//    Input::UnregisterFactory<Input::ButtonDevice>("gamepad");
//    Input::UnregisterFactory<Input::AnalogDevice>("gamepad");
//    Input::UnregisterFactory<Input::MotionDevice>("motion_emu");
//    button.reset();
//    analog.reset();
//    motion.reset();
}

-(void) resetController {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01* NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        auto hid = Service::HID::GetModule(core.GetInstance());
        Settings::values.isReloading.SetValue(false);
        if (core.GetInstance().IsPoweredOn() && hid) {
            hid->ReloadInputDevices();
        }
    });
}

-(void) rotate:(BOOL)rotate {
    Settings::values.upright_screen.SetValue(rotate);
    Settings::Apply();
}

-(void) swap:(BOOL)swap {
    Settings::values.swap_screen.SetValue(swap);
    Settings::Apply();
}

-(void) layout:(int)option {
    Settings::values.layout_option.SetValue((Settings::LayoutOption)option);
    Settings::Apply();
}

-(void) requestSave:(NSString *)path {
    _savefile = path;
    shouldSave=true;
}

-(void) requestLoad:(NSString *)path {
    _savefile = path;
    shouldLoad=true;
}

-(void) prepareAudio {
    NSError *error = nil;
    [[AVAudioSession sharedInstance]
     setCategory:AVAudioSessionCategoryAmbient
     mode:AVAudioSessionModeDefault
     options:AVAudioSessionCategoryOptionAllowBluetooth |
     AVAudioSessionCategoryOptionAllowAirPlay |
     AVAudioSessionCategoryOptionAllowBluetoothA2DP |
     AVAudioSessionCategoryOptionMixWithOthers
     error:&error];
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
}
-(void) run {
    shouldSave=false;
    shouldLoad=false;
    shouldShutdown=false;
    if (!CitraWrapper.sharedInstance.isRunning)
        auto resultStatus = core.Load(*emu_window, std::string([_path UTF8String]));
    if (!CitraWrapper.sharedInstance.isRunning)
        [NSThread detachNewThreadSelector:@selector(start) toTarget:self withObject:nil];
    CitraWrapper.sharedInstance.isRunning = true;
    CitraWrapper.sharedInstance.isPaused = false;
}
-(void) shutdown {
    core.Shutdown();
    VideoCore::g_renderer.reset();
    emu_window.reset();
    Settings::values.m_buttonA.reset();
    Settings::values.m_buttonB.reset();
    Settings::values.m_buttonX.reset();
    Settings::values.m_buttonY.reset();
    Settings::values.m_buttonL.reset();
    Settings::values.m_buttonR.reset();
    Settings::values.m_buttonStart.reset();
    Settings::values.m_buttonSelect.reset();
    Settings::values.m_buttonDpadUp.reset();
    Settings::values.m_buttonDpadDown.reset();
    Settings::values.m_buttonDpadLeft.reset();
    Settings::values.m_buttonDpadRight.reset();
    Settings::values.m_buttonDummy.reset();
    Settings::values.circle_pad.reset();
    Settings::values.motion_device.reset();
    Settings::values.touch_device.reset();
    Settings::values.touch_btn_device.reset();
    Settings::values.home_button.reset();
    Settings::values.zl.reset();
    Settings::values.zr.reset();
    Settings::values.c_stick.reset();
    Settings::values.buttons_initialized=false;
    Settings::values.extra_buttons_initialized=false;
    Settings::values.home_button_initialized=false;
    Settings::values.skip_buttons=false;
    Settings::values.skip_extra_buttons=false;
    Settings::values.skip_home_button = false;

    CitraWrapper.sharedInstance.isRunning = false;
    Core::CleanState();
    finishedShutdown=true;
    NSLog(@"Shutdown Finished");
}

-(void) start {
    // Start Loop
    while (CitraWrapper.sharedInstance.isRunning) {
        if (!CitraWrapper.sharedInstance.isPaused) {
            Core::System::ResultStatus result = core.RunLoop();
            switch (result) {
                case Core::System::ResultStatus::ShutdownRequested:
                    CitraWrapper.sharedInstance.isRunning=false;
                    [CitraWrapper.sharedInstance shutdown];
                    NSLog(@"Shutting Down (Signal)");
                    return;
                default:
                    break;
            }
        } else {
            emu_window->PollEvents();
        }
        if (shouldShutdown) {
            CitraWrapper.sharedInstance.isRunning=false;
            NSLog(@"Shutting Down");
            [CitraWrapper.sharedInstance shutdown];
            shouldShutdown = false;
            return;
        } else if (shouldSave) {
            [CitraWrapper.sharedInstance SaveState:_savefile];
            shouldSave=false;
        } else if (shouldLoad) {
            [CitraWrapper.sharedInstance LoadState:_savefile];
            shouldLoad=false;
        }
    }
    NSLog(@"Finished Run Loop");
}

-(void) handleTouchEvent:(NSArray*)touches {
    if (!CitraWrapper.sharedInstance.isRunning)
        return;
    for (int i = 0; i < touches.count; i++) {
        UITouch      *touch = [touches objectAtIndex:i];
        CGPoint       point = [touch locationInView:[touch view]];
        bool touchReleased=(touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled);
        bool touchBegan=touch.phase == UITouchPhaseBegan;
        bool touchMoved=touch.phase == UITouchPhaseMoved;
        float heightRatio=emu_window->framebuffer_layout.height / ([touch view].window.bounds.size.height * [[UIScreen mainScreen] nativeScale]);
        float widthRatio=emu_window->framebuffer_layout.width / ([touch view].window.bounds.size.width * [[UIScreen mainScreen] nativeScale]);
        if (touchBegan)
            emu_window->OnTouchEvent((point.x) * [[UIScreen mainScreen] nativeScale] * widthRatio, ((point.y) * [[UIScreen mainScreen] nativeScale] * heightRatio), true);
        if (touchMoved)
            emu_window->OnTouchMoved((point.x) * [[UIScreen mainScreen] nativeScale] * widthRatio, ((point.y) * [[UIScreen mainScreen] nativeScale] * heightRatio));
        if (touchReleased)
            emu_window->OnTouchReleased();
    }
}

-(void) touchesBegan:(CGPoint)point {
    if (!CitraWrapper.sharedInstance.isRunning)
        return;
    emu_window->OnTouchEvent((point.x * [[UIScreen mainScreen] nativeScale]) + 0.5, (point.y * [[UIScreen mainScreen] nativeScale]) + 0.5, true);
}

-(void) touchesMoved:(CGPoint)point {
    if (!CitraWrapper.sharedInstance.isRunning)
        return;
    emu_window->OnTouchMoved((point.x * [[UIScreen mainScreen] nativeScale]) + 0.5, (point.y * [[UIScreen mainScreen] nativeScale]) + 0.5);
}

-(void) touchesEnded {
    if (!CitraWrapper.sharedInstance.isRunning)
        return;
    emu_window->OnTouchReleased();
}

-(void) refreshSize:(CAMetalLayer *)surface {
#if !TARGET_OS_TV
    if (CitraWrapper.sharedInstance.isRunning)
        [self orientationChanged:[[UIDevice currentDevice] orientation] with:surface];
#else
    if (CitraWrapper.sharedInstance.isRunning) {
        NSInteger layoutOptionInteger = [[NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"landscape_layout_option"]] unsignedIntValue];
        Settings::values.layout_option.SetValue(layoutOptionInteger == 0 ? Settings::LayoutOption::MobilePortrait : (Settings::LayoutOption)layoutOptionInteger);
        emu_window->OrientationChanged(false, (__bridge CA::MetalLayer*)surface);
    }
#endif
}

#if !TARGET_OS_TV
-(void) orientationChanged:(UIDeviceOrientation)orientation with:(CAMetalLayer *)surface {
    if (CitraWrapper.sharedInstance.isRunning) {
        if (orientation == UIDeviceOrientationPortrait) {
            NSInteger layoutOptionInteger = [[NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"portrait_layout_option"]] unsignedIntValue];
            Settings::values.layout_option.SetValue(layoutOptionInteger == 0 ? Settings::LayoutOption::MobilePortrait : (Settings::LayoutOption)layoutOptionInteger);
        } else {
            NSInteger layoutOptionInteger = [[NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"landscape_layout_option"]] unsignedIntValue];
            Settings::values.layout_option.SetValue(layoutOptionInteger == 0 ? Settings::LayoutOption::MobilePortrait : (Settings::LayoutOption)layoutOptionInteger);
        }
        emu_window->OrientationChanged(orientation == UIDeviceOrientationPortrait, (__bridge CA::MetalLayer*)surface);
    }
}
#endif

-(void) SaveState:(NSString *) savePath {
    std::string path=std::string([savePath UTF8String]);
    Core::SaveState(path, _title_id);
}

-(void) LoadState:(NSString *) savePath {
    Settings::values.isReloading.SetValue(true);
    std::string path=std::string([savePath UTF8String]);
    Core::LoadState(path);

    [CitraWrapper.sharedInstance resetController];
}

-(void) addCheat:(NSString *)code {
    std::shared_ptr<Cheats::GatewayCheat> cheat = std::make_shared<Cheats::GatewayCheat>(std::string([code UTF8String]), std::string([code UTF8String]), std::string([code UTF8String]));
    cheat->SetEnabled(true);
    cheat->Execute(core.GetInstance());
}

@end
