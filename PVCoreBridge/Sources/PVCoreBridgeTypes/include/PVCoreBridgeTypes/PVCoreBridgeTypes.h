//
//  PVCoreBridgeTypes.h
//  PVCoreBridge
//
//  Objective-C forward declarations for all @objc types in PVCoreBridge.
//  Import this header in ObjC .h files instead of forward-declaring each type manually.
//
//  Usage:
//    #import <PVCoreBridgeTypes/PVCoreBridgeTypes.h>   // in .h files
//    @import PVCoreBridge;                              // in .m/.mm files (full definitions)
//

#pragma once
#import <Foundation/Foundation.h>

// MARK: - Button Enums
// All button enums are NSInteger-backed (@objc public enum ... : Int)

typedef enum CoreDeadzoneMode : NSInteger CoreDeadzoneMode;
typedef enum GameSpeed : NSInteger GameSpeed;
typedef enum GLESVersion : NSInteger GLESVersion;
typedef enum GyroMouseInputSource : NSInteger GyroMouseInputSource;
typedef enum MouseButton : NSInteger MouseButton;
typedef enum Touchpad : NSInteger Touchpad;

typedef enum PV2600Button : NSInteger PV2600Button;
typedef enum PV3DOButton : NSInteger PV3DOButton;
typedef enum PV3DSButton : NSInteger PV3DSButton;
typedef enum PV5200Button : NSInteger PV5200Button;
typedef enum PV7800Button : NSInteger PV7800Button;
typedef enum PVA8Button : NSInteger PVA8Button;
typedef enum PVCDiButton : NSInteger PVCDiButton;
typedef enum PVColecoVisionButton : NSInteger PVColecoVisionButton;
typedef enum PVDoomButton : NSInteger PVDoomButton;
typedef enum PVDOSButton : NSInteger PVDOSButton;
typedef enum PVDreamcastButton : NSInteger PVDreamcastButton;
typedef enum PVDSButton : NSInteger PVDSButton;
typedef enum PVEP128Button : NSInteger PVEP128Button;
typedef enum PVGBAButton : NSInteger PVGBAButton;
typedef enum PVGBButton : NSInteger PVGBButton;
typedef enum PVGCButton : NSInteger PVGCButton;
typedef enum PVGenesisButton : NSInteger PVGenesisButton;
typedef enum PVIntellivisionButton : NSInteger PVIntellivisionButton;
typedef enum PVJaguarButton : NSInteger PVJaguarButton;
typedef enum PVLynxButton : NSInteger PVLynxButton;
typedef enum PVMAMEButton : NSInteger PVMAMEButton;
typedef enum PVMasterSystemButton : NSInteger PVMasterSystemButton;
typedef enum PVMSXButton : NSInteger PVMSXButton;
typedef enum PVN64Button : NSInteger PVN64Button;
typedef enum PVNeoGeoButton : NSInteger PVNeoGeoButton;
typedef enum PVNESButton : NSInteger PVNESButton;
typedef enum PVNGPButton : NSInteger PVNGPButton;
typedef enum PVOdyssey2Button : NSInteger PVOdyssey2Button;
typedef enum PVPCEButton : NSInteger PVPCEButton;
typedef enum PVPCECDButton : NSInteger PVPCECDButton;
typedef enum PVPCFXButton : NSInteger PVPCFXButton;
typedef enum PVPMButton : NSInteger PVPMButton;
typedef enum PVPS2Button : NSInteger PVPS2Button;
typedef enum PVPSPButton : NSInteger PVPSPButton;
typedef enum PVPSXButton : NSInteger PVPSXButton;
typedef enum PVSaturnButton : NSInteger PVSaturnButton;
typedef enum PVSega32XButton : NSInteger PVSega32XButton;
typedef enum PVSG1000Button : NSInteger PVSG1000Button;
typedef enum PVSNESButton : NSInteger PVSNESButton;
typedef enum PVSupervisionButton : NSInteger PVSupervisionButton;
typedef enum PVTIC80Button : NSInteger PVTIC80Button;
typedef enum PVVBButton : NSInteger PVVBButton;
typedef enum PVVectrexButton : NSInteger PVVectrexButton;
typedef enum PVWiiMoteButton : NSInteger PVWiiMoteButton;
typedef enum PVWolf3DButton : NSInteger PVWolf3DButton;
typedef enum PVWSButton : NSInteger PVWSButton;

// MARK: - Core Classes (from PVEmulatorCore)

@class PVEmulatorCore;

// MARK: - Base Protocols

@protocol ResponderClient;
@protocol ButtonResponder;
@protocol JoystickResponder;
@protocol KeyboardResponder;
@protocol MouseResponder;
@protocol LightGunResponder;
@protocol TouchPadResponder;
@protocol MIDIResponder;

// MARK: - Core Protocols

@protocol ObjCBridgedCoreBridge;
@protocol PVEmulatorCoreT;
@protocol EmulatorCoreAudioDataSource;
@protocol EmulatorCoreAudioDelegate;
@protocol EmulatorCoreControllerDataSource;
@protocol EmulatorCoreIOInterface;
@protocol EmulatorCoreRumbleDataSource;
@protocol EmulatorCoreRunLoop;
@protocol EmulatorCoreSavesSerializer;
@protocol EmulatorCoreVideoDelegate;
@protocol EmulatorCoreViewportPositioning;
@protocol EmulatorCoreWaveformProvider;
@protocol CoreDeadzoneCapable;
@protocol PVRenderDelegate;
@protocol PVRenderDelegateIOSurface;
@protocol PVRenderDelegateMetal;

// MARK: - Feature Protocols

@protocol DiscSwappable;
@protocol GameWithCheat;

// MARK: - System Responder Protocols

@protocol PV2600SystemResponderClient;
@protocol PV3DOSystemResponderClient;
@protocol PV3DSSystemResponderClient;
@protocol PV5200SystemResponderClient;
@protocol PV7800SystemResponderClient;
@protocol PVA8SystemResponderClient;
@protocol PVCDiSystemResponderClient;
@protocol PVColecoVisionSystemResponderClient;
@protocol PVDOSSystemResponderClient;
@protocol PVDoomSystemResponderClient;
@protocol PVDreamcastSystemResponderClient;
@protocol PVDSSystemResponderClient;
@protocol PVEP128SystemResponderClient;
@protocol PVGBASystemResponderClient;
@protocol PVGBSystemResponderClient;
@protocol PVGameCubeSystemResponderClient;
@protocol PVGenesisSystemResponderClient;
@protocol PVIntellivisionSystemResponderClient;
@protocol PVJaguarSystemResponderClient;
@protocol PVLynxSystemResponderClient;
@protocol PVMAMESystemResponderClient;
@protocol PVMasterSystemSystemResponderClient;
@protocol PVMSXSystemResponderClient;
@protocol PVN64SystemResponderClient;
@protocol PVNESSystemResponderClient;
@protocol PVNeoGeoPocketSystemResponderClient;
@protocol PVNeoGeoSystemResponderClient;
@protocol PVOdyssey2SystemResponderClient;
@protocol PVPCECDSystemResponderClient;
@protocol PVPCESystemResponderClient;
@protocol PVPCFXSystemResponderClient;
@protocol PVPokeMiniSystemResponderClient;
@protocol PVPS2SystemResponderClient;
@protocol PVPSPSystemResponderClient;
@protocol PVPSXSystemResponderClient;
@protocol PVRetroArchCoreResponderClient;
@protocol PVSaturnSystemResponderClient;
@protocol PVSega32XSystemResponderClient;
@protocol PVSG1000SystemResponderClient;
@protocol PVSNESSystemResponderClient;
@protocol PVSupervisionSystemResponderClient;
@protocol PVTIC80SystemResponderClient;
@protocol PVVectrexSystemResponderClient;
@protocol PVVirtualBoySystemResponderClient;
@protocol PVWiiSystemResponderClient;
@protocol PVWolf3DSystemResponderClient;
@protocol PVWonderSwanSystemResponderClient;
