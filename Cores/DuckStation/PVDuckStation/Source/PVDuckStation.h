

#import <Foundation/Foundation.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVSupport/PVSupport-Swift.h>

#include <os/log.h>

NS_ASSUME_NONNULL_BEGIN

extern os_log_t OE_CORE_LOG;

PVCORE_DIRECT_MEMBERS
@interface PVDuckStationCore : PVEmulatorCore <PVPSXSystemResponderClient> {
    @public
    dispatch_semaphore_t mupenWaitToBeginFrameSemaphore;
    dispatch_semaphore_t coreWaitToEndFrameSemaphore;
}

@end

// for Swift
@interface PVDuckStationCore()
@property (nonatomic, assign) NSUInteger maxDiscs;
-(void)setMedia:(BOOL)open forDisc:(NSUInteger)disc;
-(void)changeDisplayMode;

# pragma CheatCodeSupport
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled error:(NSError**)error;
- (BOOL)getCheatSupport;
@end

__weak static PVDuckStationCore * _current;

#ifdef __cplusplus
extern "C" {
#endif

/**
 * PlayStation hacks specific to the DuckStation OpenEmu plug-in.
 * TODO: Migrate all of these to OEOverrides.ini instead of being a compile-time thing.
 */
typedef NS_OPTIONS(uint32_t, OEPSXHacks) {
        //! No OpenEmu-specific hacks available/required.
    OEPSXHacksNone = 0,

        //! Game works best with, or requires, a GunCon.
    OEPSXHacksGunCon = 1 << 0,
        //! Game works best with, or requires, a Konami Justifier.
        //! @note Currently not supported by DuckStation.
    OEPSXHacksJustifier = 2 << 0,
        //! Game works best with, or requires, a mouse.
    OEPSXHacksMouse = 3 << 0,

        //! All the hack-specific controller types.
        //! @discussion Can be <code>and</code>ed to get the specific controller type the game needs or desires.
    OEPSXHacksCustomControllers = OEPSXHacksGunCon | OEPSXHacksJustifier | OEPSXHacksMouse,

        //! Game requires only one memory card inserted.
    OEPSXHacksOnlyOneMemcard = 1 << 4,

        //! Game supports multi-tap.
        //! TODO: implement
        //! @note Currently not implemented in the DuckStation plug-in.
    OEPSXHacksMultiTap = 1 << 5,
        //! Game requires multi-tap adaptor to be in the second controller port.
        //! TODO: implement
        //! @note Currently not implemented in the DuckStation plug-in.
    OEPSXHacksMultiTap5PlayerPort2 = 1 << 6,
};

extern OEPSXHacks OEGetPSXHacksNeededForGame(NSString *name);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
