//
//  PVPlayCore.m
//  PVPlay
//
//  Created by Joseph Mattiello on 4/6/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVPlayCore.h"
#import "PVPlayCore+Controls.h"
#import "PVPlayCore+Audio.h"
#import "PVPlayCore+Video.h"

#import "PVPlayCore+Audio.h"

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import "PS2VM.h"
#import "gs/GSH_OpenGL/GSH_OpenGL.h"
#import "PadHandler.h"
#import "SoundHandler.h"
#import "PS2VM_Preferences.h"
#import "AppConfig.h"
#import "StdStream.h"

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
	CPS2VM _ps2VM;
	NSString *_romPath;
	BindingPtr _bindings[PS2::CControllerInfo::MAX_BUTTONS];
}

- (instancetype)init {
	if (self = [super init]) {
		_videoWidth  = 640;
		_videoHeight = 480;
		_videoBitDepth = 32; // ignored
		videoDepthBitDepth = 0; // TODO

		sampleRate = 44100;

		isNTSC = YES;

		dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);

		_callbackQueue = dispatch_queue_create("org.provenance-emu.play.CallbackHandlerQueue", queueAttributes);
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

	return YES;
}

#pragma mark - Running
- (void)startEmulation {
	[self setupEmulation];
	[super startEmulation];
	[self.frontBufferCondition lock];
	while (!shouldStop && self.isFrontBufferReady) [self.frontBufferCondition wait];
	[self.frontBufferCondition unlock];

}

- (void)setupEmulation
{
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
	CAppConfig::GetInstance().SetPreferenceInteger(PREF_CGSHANDLER_PRESENTATION_MODE, CGSHandler::PRESENTATION_MODE_FIT);
	CAppConfig::GetInstance().Save();

	_ps2VM.Initialize();
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
	if (flag) {
		_ps2VM.Pause();
	} else {
		_ps2VM.Resume();
	}

	[super setPauseEmulation:flag];
}

- (void)stopEmulation {
	_ps2VM.Pause();
	_ps2VM.Destroy();
	[super stopEmulation];
}

- (void)resetEmulation {
	_ps2VM.Pause();
	 _ps2VM.Reset();
	 _ps2VM.Resume();
}

@end

