//
//  PVPlayCore.m
//  PVPlay
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <PVLogging/PVLogging.h>

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <PVPlay/PVPlay-Swift.h>

#import "PVPlayCore.h"
#import "PVPlayCore+Controls.h"
#import "PVPlayCore+Audio.h"
#import "PVPlayCore+Video.h"
#import "PVPlayCore+Audio.h"
#import "PS2VM.h"
#import "gs/GSH_OpenGL/GSH_OpenGL.h"
#import "PadHandler.h"
#import "SoundHandler.h"
#import "PS2VM_Preferences.h"
#import "AppConfig.h"
#import "StdStream.h"
#include "PathUtils.h"
#include "../AppConfig.h"
#include "PreferenceDefs.h"
#include "GSH_OpenGLiOS.h"
#include "GSH_VulkaniOS.h"
#include "../ui_shared/BootablesProcesses.h"
#include "PH_Generic.h"
#include "../../tools/PsfPlayer/Source/SH_OpenAL.h"
#include "../ui_shared/StatsManager.h"
#include "PH_Generic.h"
#include "PS2VM.h"
#include "CGSH_Provenance_OGL.h"

#define SAMPLE_RATE_DEFAULT 44100

CGSH_Provenance_OGL *gsHandler = nullptr;
CPH_Generic *padHandler = nullptr;
UIView *m_view = nullptr;
CPS2VM *_ps2VM = nullptr;
CAMetalLayer* m_metal_layer = nullptr;
CAEAGLLayer *m_gl_layer = nullptr;

__weak PVPlayCore *_current = nil;

class CGSH_OpenEmu : public CGSH_OpenGL
{
public:
	static FactoryFunction	GetFactoryFunction();
	virtual void			InitializeImpl();
protected:
	virtual void			PresentBackbuffer();
};

class CSH_OpenEmu : public CSoundHandler
{
public:
	CSH_OpenEmu() {};
	virtual ~CSH_OpenEmu() {};
	virtual void		Reset();
	virtual void		Write(int16*, unsigned int, unsigned int);
	virtual bool		HasFreeBuffers();
	virtual void		RecycleBuffers();

	static FactoryFunction	GetFactoryFunction();
};

class CPH_OpenEmu : public CPadHandler
{
public:
	CPH_OpenEmu() {};
	virtual                 ~CPH_OpenEmu() {};
	void                    Update(uint8*);

	static FactoryFunction	GetFactoryFunction();
};

class CBinding
{
public:
	virtual			~CBinding() {}

	virtual void	ProcessEvent(PVPS2Button, uint32) = 0;

	virtual uint32	GetValue() const = 0;
};

typedef std::shared_ptr<CBinding> BindingPtr;

class CSimpleBinding : public CBinding
{
public:
	CSimpleBinding(PVPS2Button);
	virtual         ~CSimpleBinding();

	virtual void    ProcessEvent(PVPS2Button, uint32);

	virtual uint32  GetValue() const;

private:
	PVPS2Button     m_keyCode;
	uint32          m_state;
};

class CSimulatedAxisBinding : public CBinding
{
public:
	CSimulatedAxisBinding(PVPS2Button, PVPS2Button);
	virtual         ~CSimulatedAxisBinding();

	virtual void    ProcessEvent(PVPS2Button, uint32);

	virtual uint32  GetValue() const;

private:
	PVPS2Button     m_negativeKeyCode;
	PVPS2Button     m_positiveKeyCode;

	uint32          m_negativeState;
	uint32          m_positiveState;
};



#pragma mark - Private
@interface PVPlayCore()<PVPS2SystemResponderClient> {

}

@end

#pragma mark - PVPlayCore Begin

@implementation PVPlayCore
{
@public
    // ivars
    NSString *_romPath;
    BindingPtr _bindings[PS2::CControllerInfo::MAX_BUTTONS];
}

- (instancetype)init {
    if (self = [super init]) {
        videoBitDepth = 32; // ignored
        videoDepthBitDepth = 0; // TODO
        self.videoWidth = 640;
        self.videoHeight = 448;
        self.resFactor = 1; // 2x
//        [self setFramerateMultiplier: 1];
//        [self setGameSpeed:GameSpeedFast];
        sampleRate = SAMPLE_RATE_DEFAULT;
        isNTSC = YES;
        dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);
        _callbackQueue = dispatch_queue_create("org.provenance-emu.play.CallbackHandlerQueue", queueAttributes);
        _ps2VM = new CPS2VM();
    }
    _current = self;
    return self;
}

- (void)dealloc {
    _current = nil;
}

#pragma mark - PVEmulatorCore
- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
    NSBundle *coreBundle = [NSBundle bundleForClass:[self class]];
    const char *dataPath;
    
    // TODO: Proper path
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
    
    [self setOptionValues];
    return YES;
}

- (void)setOptionValues {
    [self parseOptions];
    // Set OpenGL or Vulkan
    CAppConfig::GetInstance().SetPreferenceInteger(PREFERENCE_VIDEO_GS_HANDLER, (self.gsPreference));
//    CAppConfig::GetInstance().SetPreferenceBoolean(PREF_CGSHANDLER_WIDESCREEN, resizeOutputToWidescreen.isOn);
    CAppConfig::GetInstance().SetPreferenceBoolean(PREF_CGSH_OPENGL_FORCEBILINEARTEXTURES, self.bilinearFiltering);
//    CAppConfig::GetInstance().SetPreferenceBoolean(PREFERENCE_AUDIO_ENABLEOUTPUT, enableAudioOutput.isOn);
    CAppConfig::GetInstance().SetPreferenceBoolean(PREFERENCE_ALTSTORE_JIT_ENABLED, true);
}

#pragma mark - Running
//- (void)startEmulation {
//    [self setupEmulation];
//    [super startEmulation];
//    [self.frontBufferCondition lock];
//    while (!shouldStop && self.isFrontBufferReady) [self.frontBufferCondition wait];
//    [self.frontBufferCondition unlock];
//
//}
//- (void)startEmulation {
//    if(!self.isRunning) {
//        [super startEmulation];
//        [NSThread detachNewThreadSelector:@selector(runGLESRenderThread) toTarget:self withObject:nil];
//    }
//}
- (void)startEmulation
{
    self.skipEmulationLoop=true;
    [self setupEmulation];
    [self startVM];
    [self setupControllers];
    [super startEmulation];
}

- (void)startVM
{
    if(self.gsPreference == PREFERENCE_VALUE_VIDEO_GS_HANDLER_VULKAN)
        _ps2VM->CreateGSHandler(CGSH_VulkaniOS::GetFactoryFunction(((CAMetalLayer*)m_metal_layer)));
    else if(self.gsPreference == PREFERENCE_VALUE_VIDEO_GS_HANDLER_OPENGL)
        _ps2VM->CreateGSHandler(CGSH_Provenance_OGL::GetFactoryFunction(
            ((CAEAGLLayer *)m_gl_layer),
            self.videoWidth,
            self.videoHeight,
            self.resFactor
        ));
    _ps2VM->CreatePadHandler(CPH_Generic::GetFactoryFunction());
    _ps2VM->CreateSoundHandler(CSH_OpenEmu::GetFactoryFunction());
    gsHandler = (CGSH_Provenance_OGL *)_ps2VM->GetGSHandler();
    padHandler = (CPH_Generic *)_ps2VM->GetPadHandler();
    gsHandler->Reset();
    CGSHandler::PRESENTATION_PARAMS presentationParams;
    auto presentationMode = static_cast<CGSHandler::PRESENTATION_MODE>(
        CAppConfig::GetInstance().GetPreferenceInteger(PREF_CGSHANDLER_PRESENTATION_MODE)
    );
    presentationParams.windowWidth = self.videoWidth * self.resFactor;
    presentationParams.windowHeight = self.videoHeight * self.resFactor;
    presentationParams.mode = presentationMode;
    _ps2VM->m_ee->m_gs->SetPresentationParams(presentationParams);
    _ps2VM->Pause();
    _ps2VM->Reset();
    CPS2OS* os = _ps2VM->m_ee->m_os;
    
    auto bootablePath = fs::path([_romPath fileSystemRepresentation]);
    if(IsBootableExecutablePath(bootablePath))
    {
        os->BootFromFile(bootablePath);
    }
    else
    {
        os->BootFromCDROM();
    }    
    // TODO: Play! starts a bunch of threads. They all need to be realtime.
    _ps2VM->Resume();
}

//- (void)runGLESRenderThread {
//    @autoreleasepool
//    {
//        [self.renderDelegate startRenderingOnAlternateThread];
////        BOOL success = gles_init();
////        assert(success);
//#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
//    EAGLContext* context = [self bestContext];
//    ILOG(@"%i", context.API);
//#endif
//        [NSThread detachNewThreadSelector:@selector(runGLESEmuThread) toTarget:self withObject:nil];
//
////        CFAbsoluteTime lastTime = CFAbsoluteTimeGetCurrent();
//
////        while (!has_init) {}
//        while ( !shouldStop )
//        {
//            [self.frontBufferCondition lock];
//            while (!shouldStop && self.isFrontBufferReady) [self.frontBufferCondition wait];
//            [self.frontBufferCondition unlock];
//
////            CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
////            CFTimeInterval deltaTime = now - lastTime;
//            while ( !shouldStop
//                   && !video_driver_cached_frame()
////                   && core_poll()
//                   ) {}
//            [self swapBuffers];
////            lastTime = now;
//        }
//    }
//}

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
-(EAGLContext*)bestContext {
    EAGLContext* context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    self.glesVersion = GLESVersion3;
    if (context == nil)
    {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        self.glesVersion = GLESVersion2;
    }

    return context;
}
#endif


- (void)setupEmulation
{
    [self initView];
    [self parseOptions];
    _current = self;
    
    CAppConfig::GetInstance().SetPreferencePath(PREF_PS2_CDROM0_PATH, [_romPath fileSystemRepresentation]);
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *mcd0 = [self.batterySavesPath stringByAppendingPathComponent:@"mcd0"];
    NSString *mcd1 = [self.batterySavesPath stringByAppendingPathComponent:@"mcd1"];
    NSString *hdd = [self.batterySavesPath stringByAppendingPathComponent:@"hdd"];
    
    if (![fm fileExistsAtPath:mcd0]) {
        [fm createDirectoryAtPath:mcd0 withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    if (![fm fileExistsAtPath:mcd1]) {
        [fm createDirectoryAtPath:mcd1 withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    if (![fm fileExistsAtPath:hdd]) {
        [fm createDirectoryAtPath:hdd withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    CAppConfig::GetInstance().SetPreferencePath(PREF_PS2_MC0_DIRECTORY, mcd0.fileSystemRepresentation);
    CAppConfig::GetInstance().SetPreferencePath(PREF_PS2_MC1_DIRECTORY, mcd1.fileSystemRepresentation);
    CAppConfig::GetInstance().SetPreferencePath(PREF_PS2_HOST_DIRECTORY, hdd.fileSystemRepresentation);
    CAppConfig::GetInstance().SetPreferencePath(PREF_PS2_ROM0_DIRECTORY, self.BIOSPath.fileSystemRepresentation);
    CAppConfig::GetInstance().SetPreferenceInteger(PREF_CGSHANDLER_PRESENTATION_MODE, CGSHandler::PRESENTATION_MODE_FILL);
    CAppConfig::GetInstance().SetPreferenceInteger(PREF_CGSH_OPENGL_RESOLUTION_FACTOR, self.resFactor);
    
    CAppConfig::GetInstance().RegisterPreferenceBoolean(PREFERENCE_UI_SHOWFPS, false);
    CAppConfig::GetInstance().RegisterPreferenceBoolean(PREFERENCE_UI_SHOWVIRTUALPAD, false);
    CAppConfig::GetInstance().RegisterPreferenceBoolean(PREFERENCE_AUDIO_ENABLEOUTPUT, true);
    CAppConfig::GetInstance().RegisterPreferenceInteger(PREFERENCE_UI_VIRTUALPADOPACITY, 100);
    CAppConfig::GetInstance().RegisterPreferenceBoolean(PREFERENCE_UI_HIDEVIRTUALPAD_CONTROLLER_CONNECTED, true);
    CAppConfig::GetInstance().RegisterPreferenceBoolean(PREFERENCE_UI_VIRTUALPAD_HAPTICFEEDBACK, false);
    //
    CAppConfig::GetInstance().SetPreferenceInteger(PREF_AUDIO_SPUBLOCKCOUNT, self.spuCount);
    CAppConfig::GetInstance().SetPreferenceBoolean(PREF_PS2_LIMIT_FRAMERATE, self.limitFPS);
    
    CAppConfig::GetInstance().Save();
    _ps2VM->Initialize();
    _ps2VM->ReloadFrameRateLimit();
    _ps2VM->ReloadSpuBlockCount();
    //
    //	_bindings[PS2::CControllerInfo::START] = std::make_shared<CSimpleBinding>(PVPS2ButtonStart);
    //	_bindings[PS2::CControllerInfo::SELECT] = std::make_shared<CSimpleBinding>(PVPS2ButtonSelect);
    //	_bindings[PS2::CControllerInfo::DPAD_LEFT] = std::make_shared<CSimpleBinding>(PVPS2ButtonLeft);
    //	_bindings[PS2::CControllerInfo::DPAD_RIGHT] = std::make_shared<CSimpleBinding>(PVPS2ButtonRight);
    //	_bindings[PS2::CControllerInfo::DPAD_UP] = std::make_shared<CSimpleBinding>(PVPS2ButtonUp);
    //	_bindings[PS2::CControllerInfo::DPAD_DOWN] = std::make_shared<CSimpleBinding>(PVPS2ButtonDown);
    //	_bindings[PS2::CControllerInfo::SQUARE] = std::make_shared<CSimpleBinding>(PVPS2ButtonSquare);
    //	_bindings[PS2::CControllerInfo::CROSS] = std::make_shared<CSimpleBinding>(PVPS2ButtonCross);
    //	_bindings[PS2::CControllerInfo::TRIANGLE] = std::make_shared<CSimpleBinding>(PVPS2ButtonTriangle);
    //	_bindings[PS2::CControllerInfo::CIRCLE] = std::make_shared<CSimpleBinding>(PVPS2ButtonCircle);
    //	_bindings[PS2::CControllerInfo::L1] = std::make_shared<CSimpleBinding>(PVPS2ButtonL1);
    //	_bindings[PS2::CControllerInfo::L2] = std::make_shared<CSimpleBinding>(PVPS2ButtonL2);
    //	_bindings[PS2::CControllerInfo::L3] = std::make_shared<CSimpleBinding>(PVPS2ButtonL3);
    //	_bindings[PS2::CControllerInfo::R1] = std::make_shared<CSimpleBinding>(PVPS2ButtonR1);
    //	_bindings[PS2::CControllerInfo::R2] = std::make_shared<CSimpleBinding>(PVPS2ButtonR2);
    //	_bindings[PS2::CControllerInfo::R3] = std::make_shared<CSimpleBinding>(PVPS2ButtonR3);
    //	_bindings[PS2::CControllerInfo::ANALOG_LEFT_X] = std::make_shared<CSimulatedAxisBinding>(PVPS2LeftAnalogLeft,PVPS2LeftAnalogRight);
    //	_bindings[PS2::CControllerInfo::ANALOG_LEFT_Y] = std::make_shared<CSimulatedAxisBinding>(PVPS2LeftAnalogUp,PVPS2LeftAnalogDown);
    //	_bindings[PS2::CControllerInfo::ANALOG_RIGHT_X] = std::make_shared<CSimulatedAxisBinding>(PVPS2RightAnalogLeft,PVPS2RightAnalogRight);
    //	_bindings[PS2::CControllerInfo::ANALOG_RIGHT_Y] = std::make_shared<CSimulatedAxisBinding>(PVPS2RightAnalogUp,PVPS2RightAnalogDown);
    
    // TODO: In Debug disable dynarec?
}

- (void)setPauseEmulation:(BOOL)flag {
    if (_ps2VM) {
        if (flag) {
            _ps2VM->Pause();
        } else {
            _ps2VM->Resume();
        }
    }
    [super setPauseEmulation:flag];
}

- (void)stopEmulation {
    shouldStop=true;
    [super stopEmulation];
    if (_ps2VM) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        _ps2VM->Pause();
        _ps2VM->DestroyGSHandler();
        _ps2VM->DestroyPadHandler();
        _ps2VM->DestroySoundHandler();
        _ps2VM->Destroy();
        delete _ps2VM;
        _ps2VM = nullptr;
    }
}

- (void)resetEmulation {
    if(_ps2VM)
    {
        _ps2VM->Pause();
        _ps2VM->Reset();
        _ps2VM->m_ee->m_os->BootFromCDROM();
        _ps2VM->Resume();
    }
}

//- (void)resetEmulation {
//    [super resetEmulation];
//    dispatch_semaphore_signal(glesWaitToBeginFrameSemaphore);
//    [self.frontBufferCondition lock];
//    [self.frontBufferCondition signal];
//    [self.frontBufferCondition unlock];
//}


//- (void)swapBuffers {
//    [self.renderDelegate didRenderFrameOnAlternateThread];
//}

//- (void)executeFrameSkippingFrame:(BOOL)skip {
//    dispatch_semaphore_signal(glesWaitToBeginFrameSemaphore);
//
//    dispatch_semaphore_wait(coreWaitToEndFrameSemaphore, [self frameTime]);
//}

//- (void)executeFrame {
//    [self executeFrameSkippingFrame:NO];
//}

- (void)initView {
    UIViewController *gl_view_controller = (UIViewController *)self.renderDelegate;
    UIViewController *view_controller = gl_view_controller.parentViewController;
    auto gsHandlerId = CAppConfig::GetInstance().GetPreferenceInteger(PREFERENCE_VIDEO_GS_HANDLER);
    auto screenBounds = [[UIScreen mainScreen] bounds];
    if(self.gsPreference == PREFERENCE_VALUE_VIDEO_GS_HANDLER_VULKAN)
    {
        CGSH_MTLViewController *cgsh_view_controller=[[CGSH_MTLViewController alloc]
                                                      initWithResFactor:self.resFactor
                                                      videoWidth: self.videoWidth
                                                      videoHeight: self.videoHeight];
        m_metal_layer=(CAMetalLayer *)cgsh_view_controller.view.layer;
        // Attach Controller to somewhere rendering won't interfere frame buffers
        [gl_view_controller addChildViewController:cgsh_view_controller];
        [cgsh_view_controller didMoveToParentViewController:gl_view_controller];
        // Add View
        m_view=cgsh_view_controller.view;
        [gl_view_controller.view addSubview:m_view];
        [m_view.topAnchor constraintEqualToAnchor:gl_view_controller.view.topAnchor constant:0].active = true;
        [m_view.leadingAnchor constraintEqualToAnchor:gl_view_controller.view.leadingAnchor constant:0].active = true;
        [m_view.trailingAnchor constraintEqualToAnchor:gl_view_controller.view.trailingAnchor constant:0].active = true;
        [m_view.bottomAnchor constraintEqualToAnchor:gl_view_controller.view.bottomAnchor constant:0].active = true;
    } else if(self.gsPreference == PREFERENCE_VALUE_VIDEO_GS_HANDLER_OPENGL) {
        CAEAGLLayer *layer=(CAEAGLLayer *)gl_view_controller.view.layer;
        GLKViewController *cgsh_view_controller = [[GLKViewController alloc]
                                                initWithNibName:nil
                                                bundle:nil];
        m_gl_layer=(CAEAGLLayer *)cgsh_view_controller.view.layer;
        // Attach Controller to somewhere rendering won't interfere frame buffers
        [gl_view_controller addChildViewController:cgsh_view_controller];
        [cgsh_view_controller didMoveToParentViewController:gl_view_controller];
        // Add View
        m_view=cgsh_view_controller.view;
        [gl_view_controller.view addSubview:m_view];
        // Settings
        cgsh_view_controller.view.contentScaleFactor = CGFloat(self.resFactor / [UIScreen mainScreen].scale);
        m_gl_layer.contentsScale = 1;
        gl_view_controller.view.autoresizesSubviews = true;
        gl_view_controller.view.clipsToBounds = true;
        m_view.frame = CGRectMake(0, 0,
                                   CGFloat(self.videoWidth * self.resFactor),
                                   CGFloat(self.videoHeight * self.resFactor));
        m_view.translatesAutoresizingMaskIntoConstraints = false;
        m_view.contentMode = UIViewContentModeScaleToFill;
        m_view.translatesAutoresizingMaskIntoConstraints = false;
        [m_view.topAnchor constraintEqualToAnchor:gl_view_controller.view.topAnchor constant:0].active = true;
        [m_view.leadingAnchor constraintEqualToAnchor:gl_view_controller.view.leadingAnchor constant:0].active = true;
        [m_view.trailingAnchor constraintEqualToAnchor:gl_view_controller.view.trailingAnchor constant:0].active = true;
        [m_view.bottomAnchor constraintEqualToAnchor:gl_view_controller.view.bottomAnchor constant:0].active = true;
    }
}
@end


CGSH_OpenGLiOS::CGSH_OpenGLiOS(CAEAGLLayer* layer)
    : m_layer(layer)
{
}

CGSH_OpenGLiOS::~CGSH_OpenGLiOS()
{
}

CGSHandler::FactoryFunction CGSH_OpenGLiOS::GetFactoryFunction(CAEAGLLayer* layer)
{
    return [layer]() { return new CGSH_OpenGLiOS(layer); };
}

void CGSH_OpenGLiOS::InitializeImpl()
{
    m_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];

    if(!m_context)
    {
        ELOG(@"Failed to create ES context");
        return;
    }

    if(![EAGLContext setCurrentContext:m_context])
    {
        ELOG(@"Failed to set ES context current");
        return;
    }

    CreateFramebuffer();

    {
        PRESENTATION_PARAMS presentationParams;
        presentationParams.mode = PRESENTATION_MODE_FILL;
        presentationParams.windowWidth = m_framebufferWidth;
        presentationParams.windowHeight = m_framebufferHeight;

        SetPresentationParams(presentationParams);
    }

    CGSH_OpenGL::InitializeImpl();
}

void CGSH_OpenGLiOS::PresentBackbuffer()
{
    glBindRenderbuffer(GL_RENDERBUFFER, m_colorRenderbuffer);
    CHECKGLERROR();

    BOOL success = [m_context presentRenderbuffer:GL_RENDERBUFFER];
    assert(success == YES);
}

void CGSH_OpenGLiOS::CreateFramebuffer()
{
    assert(m_defaultFramebuffer == 0);

    glGenFramebuffers(1, &m_defaultFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, m_defaultFramebuffer);

    // Create color render buffer and allocate backing store.
    glGenRenderbuffers(1, &m_colorRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, m_colorRenderbuffer);
    [m_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:m_layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &m_framebufferWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &m_framebufferHeight);

    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, m_colorRenderbuffer);

    CHECKGLERROR();

    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        ELOG(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        assert(false);
    }

    m_presentFramebuffer = m_defaultFramebuffer;
}

#pragma mark - Graphics callbacks

static CGSHandler *GSHandlerFactory()
{
    return new CGSH_OpenEmu();
}

CGSHandler::FactoryFunction CGSH_OpenEmu::GetFactoryFunction()
{
    return GSHandlerFactory;
}

void CGSH_OpenEmu::InitializeImpl()
{
    GET_CURRENT_OR_RETURN();

    // TODO: provenance doesn't have this
//    [current.renderDelegate willRenderFrameOnAlternateThread];
    CGSH_OpenGL::InitializeImpl();

    // TODO: provenance doesn't have this
//    this->m_presentFramebuffer = [current.renderDelegate.presentationFramebuffer intValue];

    glClearColor(0,0,0,0);
    glClear(GL_COLOR_BUFFER_BIT);
}

void CGSH_OpenEmu::PresentBackbuffer()
{
    GET_CURRENT_OR_RETURN();

    [current.renderDelegate didRenderFrameOnAlternateThread];

    // Start the next one.
    // TODO: provenance doesn't have this
//    [current.renderDelegate willRenderFrameOnAlternateThread];
}


#pragma mark - Pad callbacks

void CPH_OpenEmu::Update(uint8* ram)
{
    GET_CURRENT_OR_RETURN();

    for(auto listenerIterator(std::begin(m_listeners));
        listenerIterator != std::end(m_listeners); listenerIterator++)
    {
        auto* listener(*listenerIterator);

        for(unsigned int i = 0; i < PS2::CControllerInfo::MAX_BUTTONS; i++)
        {
            const auto& binding = current->_bindings[i];
            if(!binding) continue;
            uint32 value = binding->GetValue();
            auto currentButtonId = static_cast<PS2::CControllerInfo::BUTTON>(i);
            if(PS2::CControllerInfo::IsAxis(currentButtonId))
            {
                listener->SetAxisState(0, currentButtonId, value & 0xFF, ram);
            }
            else
            {
                listener->SetButtonState(0, currentButtonId, value != 0, ram);
            }
        }
    }
}

static CPadHandler *PadHandlerFactory()
{
    return new CPH_OpenEmu();
}

CPadHandler::FactoryFunction CPH_OpenEmu::GetFactoryFunction()
{
    return PadHandlerFactory;
}

#pragma mark -

//CSimpleBinding::CSimpleBinding(OEPS2Button keyCode)
//: m_keyCode(keyCode)
//, m_state(0)
//{
//
//}
//
//CSimpleBinding::~CSimpleBinding() = default;
//
//void CSimpleBinding::ProcessEvent(OEPS2Button keyCode, uint32 state)
//{
//    if(keyCode != m_keyCode) return;
//    m_state = state;
//}
//
//uint32 CSimpleBinding::GetValue() const
//{
//    return m_state;
//}

#pragma mark -

CSimulatedAxisBinding::CSimulatedAxisBinding(PVPS2Button negativeKeyCode, PVPS2Button positiveKeyCode)
: m_negativeKeyCode(negativeKeyCode)
, m_positiveKeyCode(positiveKeyCode)
, m_negativeState(0)
, m_positiveState(0)
{

}

CSimulatedAxisBinding::~CSimulatedAxisBinding() = default;

void CSimulatedAxisBinding::ProcessEvent(PVPS2Button keyCode, uint32_t state)
{
    if(keyCode == m_negativeKeyCode)
    {
        m_negativeState = state;
    }

    if(keyCode == m_positiveKeyCode)
    {
        m_positiveState = state;
    }
}

uint32_t CSimulatedAxisBinding::GetValue() const
{
    uint32 value = 0x7F;

    if(m_negativeState)
    {
        value -= m_negativeState;
    } else
    if(m_positiveState)
    {
        value += m_positiveState;
    }

    return value;
}

#pragma mark - Sound callbacks

void CSH_OpenEmu::Reset()
{

}

bool CSH_OpenEmu::HasFreeBuffers()
{
    return true;
}

void CSH_OpenEmu::RecycleBuffers()
{

}

void CSH_OpenEmu::Write(int16 *audio, unsigned int sampleCount, unsigned int sampleRate)
{
    GET_CURRENT_OR_RETURN();

    OERingBuffer *rb = [current ringBufferAtIndex:0];
    [rb write:audio maxLength:sampleCount*2];
}

void MakeCurrentThreadRealTime();
static CSoundHandler *SoundHandlerFactory()
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        MakeCurrentThreadRealTime();
    });
//    OESetThreadRealtime(1. / (1 * 60), .007, .03);
    return new CSH_OpenEmu();
}

CSoundHandler::FactoryFunction CSH_OpenEmu::GetFactoryFunction()
{
    return SoundHandlerFactory;
}

#pragma mark - Threads
#include <mach/mach.h>
#include <mach/mach_time.h>
void move_pthread_to_realtime_scheduling_class(pthread_t pthread);
void MakeCurrentThreadRealTime()
{
    move_pthread_to_realtime_scheduling_class(pthread_self());
}

void move_pthread_to_realtime_scheduling_class(pthread_t pthread)
{
    mach_timebase_info_data_t timebase_info;
    mach_timebase_info(&timebase_info);

    const uint64_t NANOS_PER_MSEC = 1000000ULL;
    double clock2abs = ((double)timebase_info.denom / (double)timebase_info.numer) * NANOS_PER_MSEC;

    thread_time_constraint_policy_data_t policy;
    policy.period      = 0;
    policy.computation = (uint32_t)(5 * clock2abs); // 5 ms of work
    policy.constraint  = (uint32_t)(10 * clock2abs);
    policy.preemptible = FALSE;

    int kr = thread_policy_set(pthread_mach_thread_np(pthread_self()),
                               THREAD_TIME_CONSTRAINT_POLICY,
                               (thread_policy_t)&policy,
                               THREAD_TIME_CONSTRAINT_POLICY_COUNT);
    if (kr != KERN_SUCCESS) {
        mach_error("thread_policy_set:", kr);
        exit(1);
    }
}
