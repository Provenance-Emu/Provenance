//
//  PVMelonDSCore+Netplay.mm
//  PVMelonDS
//
//  Created by Joseph Mattiello on 3/22/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#import "PVMelonDSCore+Netplay.h"
#import <objc/runtime.h>

// ---------------------------------------------------------------------------
// Conditional LocalMP inclusion
//
// When the melonDS native submodule is present (Cores/melonDS/melonDS/src/),
// we link directly against LocalMP.  When it is absent (e.g. CI builds that
// only have the libretro wrapper), we stub the namespace so the rest of the
// bridge code compiles cleanly and reports "unavailable" at runtime.
// ---------------------------------------------------------------------------
#if __has_include("../../melonDS/src/LocalMP.h")
#include "../../melonDS/src/LocalMP.h"
#define PVMELON_LOCAL_MP_AVAILABLE 1
#else
#define PVMELON_LOCAL_MP_AVAILABLE 0
// Minimal stub so the rest of the .mm compiles without the submodule.
namespace LocalMP {
    static inline bool Init(uint16_t /*port_base*/ = 7064) { return false; }
    static inline void DeInit() {}
    static inline bool IsConnected() { return false; }
}
#endif

NSErrorDomain const PVMelonDSLocalMPErrorDomain = @"org.provenance-emu.melonds.localmp";

// ---------------------------------------------------------------------------
// Private ivar storage via associated objects
//
// Self-referential pointers guarantee unique addresses even if the linker
// merges const-zero data sections (matches pattern used by PPSSPP netplay).
// ---------------------------------------------------------------------------
static const void *kLocalMPStatusKey = &kLocalMPStatusKey;

@implementation PVMelonDSCoreBridge (Netplay)

// MARK: - Class property

+ (BOOL)localMPAvailable {
    return PVMELON_LOCAL_MP_AVAILABLE ? YES : NO;
}

// MARK: - Instance property

- (PVMelonDSLocalMPStatus)localMPStatus {
    NSNumber *boxed = objc_getAssociatedObject(self, kLocalMPStatusKey);
    PVMelonDSLocalMPStatus cachedStatus = boxed ? (PVMelonDSLocalMPStatus)boxed.integerValue : PVMelonDSLocalMPStatusIdle;

#if PVMELON_LOCAL_MP_AVAILABLE
    bool connected = LocalMP::IsConnected();

    if (cachedStatus == PVMelonDSLocalMPStatusActive && !connected) {
        // Underlying LocalMP disconnected; sync bookkeeping.
        [self _setLocalMPStatus:PVMelonDSLocalMPStatusIdle];
        return PVMelonDSLocalMPStatusIdle;
    }

    if (cachedStatus == PVMelonDSLocalMPStatusIdle && connected) {
        // LocalMP reports active even though we think idle; sync bookkeeping.
        [self _setLocalMPStatus:PVMelonDSLocalMPStatusActive];
        return PVMelonDSLocalMPStatusActive;
    }
#endif

    return cachedStatus;
}

- (void)_setLocalMPStatus:(PVMelonDSLocalMPStatus)status {
    objc_setAssociatedObject(self, kLocalMPStatusKey,
                             @(status), OBJC_ASSOCIATION_RETAIN);
}

// MARK: - Control

- (BOOL)startLocalMPWithPortBase:(uint16_t)portBase
                           error:(NSError *__autoreleasing _Nullable *)error {
#if !PVMELON_LOCAL_MP_AVAILABLE
    if (error) {
        *error = [NSError errorWithDomain:PVMelonDSLocalMPErrorDomain
                                     code:PVMelonDSLocalMPErrorUnavailable
                                 userInfo:@{
            NSLocalizedDescriptionKey: @"melonDS local wireless is not available in this build."
        }];
    }
    return NO;
#else
    if (self.localMPStatus != PVMelonDSLocalMPStatusIdle) {
        if (error) {
            *error = [NSError errorWithDomain:PVMelonDSLocalMPErrorDomain
                                         code:PVMelonDSLocalMPErrorAlreadyActive
                                     userInfo:@{
                NSLocalizedDescriptionKey: @"A local wireless session is already active."
            }];
        }
        return NO;
    }

    if (!LocalMP::Init(portBase)) {
        if (error) {
            *error = [NSError errorWithDomain:PVMelonDSLocalMPErrorDomain
                                         code:PVMelonDSLocalMPErrorInitFailed
                                     userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"LocalMP::Init(%u) failed — check that UDP port %u is not in use.",
                    (unsigned)portBase, (unsigned)portBase]
            }];
        }
        return NO;
    }

    [self _setLocalMPStatus:PVMelonDSLocalMPStatusActive];
    return YES;
#endif
}

- (void)stopLocalMP {
    if (self.localMPStatus == PVMelonDSLocalMPStatusIdle) { return; }
#if PVMELON_LOCAL_MP_AVAILABLE
    LocalMP::DeInit();
#endif
    [self _setLocalMPStatus:PVMelonDSLocalMPStatusIdle];
}

@end
