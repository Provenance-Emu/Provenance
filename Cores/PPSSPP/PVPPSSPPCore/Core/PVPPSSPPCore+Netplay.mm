//
//  PVPPSSPPCore+Netplay.mm
//  PVPPSSPP
//
//  Created by Joseph Mattiello on 3/21/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#import "PVPPSSPPCore+Netplay.h"
#import <objc/runtime.h>

#include <atomic>
#include <cctype>
#include <mutex>
#include <string>

// PPSSPP config globals and the ad hoc state this file reads.
#include "Core/Config.h"
#include "Core/HLE/proAdhoc.h"
#include "Core/HLE/sceNetAdhoc.h"

NSErrorDomain const PVPPSSPPAdhocErrorDomain = @"org.provenance-emu.ppsspp.adhoc";

/// UserDefaults key for this install's persisted ad hoc MAC address.
static NSString * const kAdhocMACDefaultsKey = @"org.provenance-emu.ppsspp.adhocMAC";

/// A MAC address is "xx:xx:xx:xx:xx:xx".
static const NSUInteger kMACAddressLength = 17;
static const int kMACOctetCount = 6;
/// Clears the multicast and locally-administered bits of the first octet, as
/// PPSSPP's own `CreateRandMAC` does: some games (Gran Turismo) reject a MAC
/// with either set.
static const uint32_t kMACFirstOctetMask = 0xFC;

/// PPSSPP's default hosted ad hoc server, used when a stale loopback address
/// would otherwise put the game into single-machine mode.
static const char * const kDefaultAdhocServer = "socom.cc";

// ---------------------------------------------------------------------------
// Session state
// ---------------------------------------------------------------------------

namespace {

/// What `g_Config` held before netplay changed it, so `-stopAdhoc` can put it back.
struct AdhocSnapshot {
    bool wlan;
    bool adhocServer;
    std::string server;
};

/// The configuration the current session wants on every boot.
struct AdhocPending {
    bool active = false;
    bool wlan = false;
    bool adhocServer = false;
    std::string server;
};

/// Guards the session state below: `-applyAdhocBootConfig` runs on the runVM
/// queue while sessions start and stop on the main thread.
std::mutex s_stateMutex;
AdhocPending s_pending;
bool s_hasSnapshot = false;
AdhocSnapshot s_snapshot {};
/// The session ended while the game's ad hoc layer was running, so the server
/// string could not be restored safely; the next boot restores it.
bool s_restoreOnBoot = false;

/// What the running game was booted with. The port offset, the built-in server
/// and `isLocalServer` are read only by `PSP_Init`, so a change to them needs
/// a restart. Recorded by `-applyAdhocBootConfig`, the last call before boot.
bool s_bootAdhocServer = false;
int s_bootPortOffset = 0;

/// The last peer count read, returned while `peerlock` is busy.
std::atomic<NSInteger> s_lastPeerCount {0};

/// PPSSPP's ad hoc threads read `g_Config.proAdhocServer` (a std::string)
/// without a lock while the layer is up, so it may only be written when it is not.
bool AdhocLayerIdle() {
    return !netAdhocctlInited && !friendFinderRunning;
}

bool IsLoopbackServer(const std::string &server) {
    // Same test as InitLocalhostIP in HLE/sceNet.cpp, which strips spaces first.
    const auto isSpace = [](unsigned char c) { return std::isspace(c) != 0; };
    auto begin = server.begin();
    auto end = server.end();
    while (begin != end && isSpace(*begin)) { ++begin; }
    while (end != begin && isSpace(*(end - 1))) { --end; }
    const std::string stripped(begin, end);
    return strcasecmp(stripped.c_str(), "localhost") == 0 || stripped.find("127.") == 0;
}

} // namespace

// Use self-referential pointers so each key has a unique address even if the
// compiler/linker merges const-zero data (the usual self-referential key pattern).
static const void *kAdhocStatusKey = &kAdhocStatusKey;

@implementation PVPPSSPPCoreBridge (Netplay)

// MARK: - Properties

- (PVPPSSPPAdhocStatus)adhocStatus {
    NSNumber *boxed = objc_getAssociatedObject(self, kAdhocStatusKey);
    return boxed ? (PVPPSSPPAdhocStatus)boxed.integerValue : PVPPSSPPAdhocStatusIdle;
}

- (void)setAdhocStatus:(PVPPSSPPAdhocStatus)status {
    objc_setAssociatedObject(self, kAdhocStatusKey,
                             @(status), OBJC_ASSOCIATION_RETAIN);
}

- (nullable NSString *)adhocServerAddress {
    if (!g_Config.bEnableWlan) { return nil; }
    const std::string &addr = g_Config.proAdhocServer;
    if (addr.empty()) { return nil; }
    return [NSString stringWithUTF8String:addr.c_str()];
}

- (BOOL)wlanEnabled {
    return g_Config.bEnableWlan ? YES : NO;
}

- (BOOL)adhocSessionConnected {
    return (netAdhocctlInited && adhocctlState == ADHOCCTL_STATE_CONNECTED) ? YES : NO;
}

- (NSInteger)adhocPeerCount {
    if (!friendFinderRunning) {
        s_lastPeerCount = 0;
        return 0;
    }
    // `friends` is rewritten by the friend-finder thread under `peerlock`, and
    // that thread's lock order (proAdhoc.cpp) must not be waited on from here:
    // keep the last count when the lock is busy.
    std::unique_lock<std::recursive_mutex> guard(peerlock, std::try_to_lock);
    if (!guard.owns_lock()) {
        return s_lastPeerCount;
    }
    s_lastPeerCount = getActivePeerCount();
    return s_lastPeerCount;
}

// MARK: - MAC address

+ (NSString *)adhocMACAddress {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *saved = [defaults stringForKey:kAdhocMACDefaultsKey];
    if (saved.length == kMACAddressLength) { return saved; }

    NSMutableArray<NSString *> *octets = [NSMutableArray arrayWithCapacity:kMACOctetCount];
    for (int i = 0; i < kMACOctetCount; i++) {
        uint32_t octet = arc4random_uniform(256);
        if (i == 0) { octet &= kMACFirstOctetMask; }
        [octets addObject:[NSString stringWithFormat:@"%02x", octet]];
    }
    NSString *generated = [octets componentsJoinedByString:@":"];
    [defaults setObject:generated forKey:kAdhocMACDefaultsKey];
    return generated;
}

// MARK: - Boot configuration

- (void)applyAdhocBootConfig {
    // These do not depend on a session and must never be empty or shared:
    // the offset has to match on every device, an empty MAC logs in as
    // 00:00:00:00:00:00, and UPnP would try to open ports on the router.
    g_Config.iPortOffset = PVPPSSPPAdhocPortOffset;
    g_Config.sMACAddress = std::string([[PVPPSSPPCoreBridge adhocMACAddress] UTF8String]);
    g_Config.bEnableUPnP = false;

    std::lock_guard<std::mutex> lock(s_stateMutex);
    if (s_pending.active) {
        g_Config.bEnableWlan = s_pending.wlan;
        g_Config.bEnableAdhocServer = s_pending.adhocServer;
        g_Config.proAdhocServer = s_pending.server;
    } else if (s_restoreOnBoot && s_hasSnapshot) {
        // A session ended while the ad hoc layer was up; put its settings back now.
        g_Config.bEnableWlan = s_snapshot.wlan;
        g_Config.bEnableAdhocServer = s_snapshot.adhocServer;
        g_Config.proAdhocServer = s_snapshot.server;
        s_restoreOnBoot = false;
        s_hasSnapshot = false;
    } else if (IsLoopbackServer(g_Config.proAdhocServer)) {
        // A loopback server makes PPSSPP bind every socket to loopback.
        g_Config.proAdhocServer = kDefaultAdhocServer;
    }

    s_bootAdhocServer = g_Config.bEnableWlan && g_Config.bEnableAdhocServer;
    s_bootPortOffset = g_Config.iPortOffset;
}

// MARK: - Control

- (NSError *)adhocErrorWithCode:(PVPPSSPPAdhocError)code message:(NSString *)message {
    return [NSError errorWithDomain:PVPPSSPPAdhocErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: message }];
}

/// Validates that a session may start; returns NO and fills `error` otherwise.
- (BOOL)prepareAdhocStartWithError:(NSError *__autoreleasing _Nullable *)error {
    if (self.adhocStatus != PVPPSSPPAdhocStatusIdle) {
        if (error) {
            *error = [self adhocErrorWithCode:PVPPSSPPAdhocErrorAlreadyActive
                                      message:@"An adhoc session is already active."];
        }
        return NO;
    }
    if (!_isInitialized) {
        if (error) {
            *error = [self adhocErrorWithCode:PVPPSSPPAdhocErrorNotReady
                                      message:@"The PPSSPP core is not ready to start adhoc networking."];
        }
        return NO;
    }
    return YES;
}

/// Capture g_Config values before netplay overwrites them so stopAdhoc can
/// restore them. Caller holds `s_stateMutex`.
- (void)savePriorAdhocConfigLocked {
    if (s_hasSnapshot && s_restoreOnBoot) {
        // The previous session's settings were never put back; they are the real prior ones.
        s_restoreOnBoot = false;
        return;
    }
    s_snapshot.wlan = g_Config.bEnableWlan;
    s_snapshot.adhocServer = g_Config.bEnableAdhocServer;
    s_snapshot.server = g_Config.proAdhocServer;
    s_hasSnapshot = true;
}

- (BOOL)startAdhocLANHostWithAddress:(NSString *)lanAddress
                     restartRequired:(BOOL * _Nullable)restartRequired
                               error:(NSError *__autoreleasing _Nullable *)error {
    NSAssert([NSThread isMainThread], @"startAdhocLANHostWithAddress:restartRequired:error: must be called on the main thread");
    if (![self prepareAdhocStartWithError:error]) { return NO; }

    const std::string address = std::string([lanAddress UTF8String] ?: "");
    if (address.empty() || IsLoopbackServer(address)) {
        // Hosting on loopback is PPSSPP's single-machine mode: no other device can join.
        if (error) {
            *error = [self adhocErrorWithCode:PVPPSSPPAdhocErrorInvalidAddress
                                      message:@"Hosting needs this device's Wi-Fi address. Connect to a Wi-Fi network and try again."];
        }
        return NO;
    }

    BOOL restart;
    {
        std::lock_guard<std::mutex> lock(s_stateMutex);
        [self savePriorAdhocConfigLocked];
        s_pending.active = true;
        s_pending.wlan = true;
        s_pending.adhocServer = true;
        s_pending.server = address;

        // The server string applies live only while the ad hoc layer is idle;
        // otherwise the restart re-applies the pending session.
        const BOOL layerIdle = AdhocLayerIdle();
        if (layerIdle) {
            g_Config.proAdhocServer = address;
        }
        g_Config.bEnableWlan = true;
        g_Config.bEnableAdhocServer = true;

        // The built-in server and port offset apply only on the next boot.
        restart = !layerIdle ||
            !(s_bootAdhocServer && s_bootPortOffset == PVPPSSPPAdhocPortOffset && !isLocalServer);
    }
    if (restartRequired) { *restartRequired = restart; }
    [self setAdhocStatus:PVPPSSPPAdhocStatusHosting];
    return YES;
}

- (BOOL)connectToAdhocServer:(NSString *)host
             restartRequired:(BOOL * _Nullable)restartRequired
                       error:(NSError *__autoreleasing _Nullable *)error {
    NSAssert([NSThread isMainThread], @"connectToAdhocServer:restartRequired:error: must be called on the main thread");
    if (!host || host.length == 0) {
        if (error) {
            *error = [self adhocErrorWithCode:PVPPSSPPAdhocErrorInvalidAddress
                                      message:@"Adhoc server address must not be empty."];
        }
        return NO;
    }
    if (![self prepareAdhocStartWithError:error]) { return NO; }

    const std::string address = std::string([host UTF8String]);
    BOOL restart;
    {
        std::lock_guard<std::mutex> lock(s_stateMutex);
        [self savePriorAdhocConfigLocked];
        s_pending.active = true;
        s_pending.wlan = true;
        s_pending.adhocServer = false;
        s_pending.server = address;

        const BOOL layerIdle = AdhocLayerIdle();
        if (layerIdle) {
            g_Config.proAdhocServer = address;
        }
        g_Config.bEnableWlan = true;
        g_Config.bEnableAdhocServer = false;

        // The server address is otherwise read live. A restart is needed if the
        // game booted with a different port offset or in single-machine
        // (loopback) mode, or if the string could not be written live.
        restart = !layerIdle || (s_bootPortOffset != PVPPSSPPAdhocPortOffset) || isLocalServer;
    }
    if (restartRequired) { *restartRequired = restart; }

    // NOTE: PVPPSSPPAdhocStatusConnected means "configured as a client". PPSSPP
    // exposes no callback for the TCP handshake; the game's own ad hoc session
    // comes up when the player opens its multiplayer menu (see
    // `adhocSessionConnected`).
    [self setAdhocStatus:PVPPSSPPAdhocStatusConnected];
    return YES;
}

- (void)stopAdhoc {
    NSAssert([NSThread isMainThread], @"stopAdhoc must be called on the main thread");
    std::lock_guard<std::mutex> lock(s_stateMutex);

    // If no prior values were ever saved and we're already idle, do nothing.
    // This avoids unintentionally wiping the user's PPSSPP WLAN/adhoc settings
    // when stopAdhoc is called during teardown without an active netplay session.
    if (!s_hasSnapshot && self.adhocStatus == PVPPSSPPAdhocStatusIdle) {
        return;
    }

    // Forget the session first so a later boot no longer applies it.
    s_pending = AdhocPending {};

    if (s_hasSnapshot) {
        g_Config.bEnableWlan = s_snapshot.wlan;
        g_Config.bEnableAdhocServer = s_snapshot.adhocServer;
        if (AdhocLayerIdle()) {
            g_Config.proAdhocServer = s_snapshot.server;
            s_hasSnapshot = false;
        } else {
            // The ad hoc threads may be reading the string; the next boot restores it.
            s_restoreOnBoot = true;
        }
    }
    [self setAdhocStatus:PVPPSSPPAdhocStatusIdle];
}

@end
