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

@interface PVPicoDriveBridge (RetroAchievements)
/// Pointer to libretro RETRO_MEMORY_SYSTEM_RAM (Genesis 68K work RAM, etc.).
@property (nonatomic, readonly, nullable) void *systemRAMPtr;
/// Size in bytes of the active system RAM region.
@property (nonatomic, readonly) NSUInteger systemRAMSize;
@end

NS_HEADER_AUDIT_END(nullability, sendability)
