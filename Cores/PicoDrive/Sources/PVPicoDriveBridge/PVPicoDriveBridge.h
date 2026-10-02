@import Foundation;
@import PVCoreObjCBridge;

// Forward Declerations
@protocol ObjCBridgedCoreBridge;
@protocol PVSega32XSystemResponderClient;
typedef enum PVSega32XButton: NSInteger PVSega32XButton;

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface PVPicoDriveBridge: PVCoreObjCBridge <ObjCBridgedCoreBridge>
- (BOOL)loadFileAtPath:(NSString *)path error:(NSError *__autoreleasing *)error;
/// Called on the emulation thread after every emulated frame. The emulation loop
/// runs inside this bridge, so the Swift core's `executeFrame()` is never called;
/// RetroAchievements ticks through this hook instead. Declared in the main
/// @interface because SwiftPM module synthesis can drop ObjC categories.
@property (nonatomic, copy, nullable) void (^frameCompletedHandler)(void);
@end

@interface PVPicoDriveBridge (PVSega32XSystemResponderClient) <PVSega32XSystemResponderClient>
#pragma clang diagnostic pop
- (void)didPushSega32XButton:(PVSega32XButton)button forPlayer:(NSUInteger)player;
- (void)didReleaseSega32XButton:(PVSega32XButton)button forPlayer:(NSUInteger)player;
@end

@interface PVPicoDriveBridge (Cheats)
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType
        setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError **)error;
- (void)resetCheatCodes;
@end

/// Hardware PicoDrive is currently emulating, derived from `PicoIn.AHW`.
typedef NS_ENUM(NSInteger, PVPicoDriveActiveHardware) {
    /// No content loaded.
    PVPicoDriveActiveHardwareNone = 0,
    /// Mega Drive / Genesis incl. SVP (also a 32X cart before the 68K enables the adapter).
    PVPicoDriveActiveHardwareMegaDrive,
    /// 32X adapter started (`PAHW_32X`) and its memory allocated.
    PVPicoDriveActiveHardwareSega32X,
    /// Sega CD / Mega-CD (`PAHW_MCD`), including 32X CD titles.
    PVPicoDriveActiveHardwareSegaCD,
    /// Master System (`PAHW_SMS` without GG/SG/SC bits).
    PVPicoDriveActiveHardwareMasterSystem,
    /// Game Gear (`PAHW_GG`).
    PVPicoDriveActiveHardwareGameGear,
    /// SG-1000 / SC-3000 / Sega Pico: no rcheevos map wired here.
    PVPicoDriveActiveHardwareOther
};

/// Host memory blocks PicoDrive can expose to RetroAchievements. Each is the raw
/// emulator buffer (PicoDrive stores 16-bit-bus RAM as host-order words), exactly
/// what upstream libretro/picodrive hands RetroArch via SET_MEMORY_MAPS.
typedef NS_ENUM(NSInteger, PVPicoDriveMemoryRegion) {
    /// Mega Drive 68K work RAM (`PicoMem.ram`, 64 KiB).
    PVPicoDriveMemoryRegionMain68KRAM = 0,
    /// Master System / Game Gear Z80 RAM (`PicoMem.zram`, 8 KiB).
    PVPicoDriveMemoryRegionZ80WorkRAM,
    /// 32X SH-2 SDRAM (`Pico32xMem->sdram`, 256 KiB).
    PVPicoDriveMemoryRegionSega32XSDRAM,
    /// Sega CD program RAM (`Pico_mcd->prg_ram`, 512 KiB).
    PVPicoDriveMemoryRegionSegaCDProgramRAM,
    /// Sega CD word RAM, 2M layout (`Pico_mcd->word_ram2M`, 256 KiB).
    PVPicoDriveMemoryRegionSegaCDWordRAM,
    /// Cartridge save RAM (`Pico.sv.data`, size varies, may be absent).
    PVPicoDriveMemoryRegionCartridgeRAM
};

@interface PVPicoDriveBridge (RetroAchievements)
/// Hardware currently emulated; `None` until content is loaded.
@property (nonatomic, readonly) PVPicoDriveActiveHardware activeHardware;
/// Host pointer to `region`, or NULL when that hardware is not active/allocated.
/// `size` receives the buffer size in bytes (0 when NULL is returned).
- (nullable void *)memoryPointerForRegion:(PVPicoDriveMemoryRegion)region size:(NSUInteger *)size;
@end

NS_HEADER_AUDIT_END(nullability, sendability)
