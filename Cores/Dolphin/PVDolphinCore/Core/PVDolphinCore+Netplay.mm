//
//  PVDolphinCore+Netplay.mm
//  PVDolphin
//
//  Created by Joseph Mattiello on 3/22/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Objective-C++ bridge between Dolphin's C++ netplay subsystem and the
//  Provenance PVNetplayCapable protocol.
//
//  The Dolphin C++ includes are guarded with HAVE_DOLPHIN_NETPLAY so that
//  this file compiles cleanly in CI environments where the dolphin-ios
//  submodule has not been initialised.  When the submodule is present the
//  full implementation is compiled in.
//

#import "PVDolphinCore+Netplay.h"
@import PVLoggingObjC;
#import <objc/runtime.h>

// ---------------------------------------------------------------------------
// MARK: - Dolphin C++ netplay API
//
// Dolphin's netplay lives in:
//   Source/Core/Core/NetPlayClient.h  →  NetPlay::NetPlayClient
//   Source/Core/Core/NetPlayServer.h  →  NetPlay::NetPlayServer
//   Source/Core/Core/Config/NetplaySettings.h  →  Config::NETPLAY_*
//
// NetTraversalConfig may be in Common/TraversalClient.h or inlined in the
// NetPlay headers depending on the Dolphin revision.
// ---------------------------------------------------------------------------

#if __has_include("Core/NetPlayClient.h") && __has_include(<SFML/Network/Packet.hpp>)
    #define HAVE_DOLPHIN_NETPLAY 1
    #include "Core/NetPlayClient.h"
    #include "Core/NetPlayServer.h"
    #if __has_include("Core/Config/NetplaySettings.h")
        #include "Core/Config/NetplaySettings.h"
    #endif
    #if __has_include("Common/TraversalClient.h")
        #include "Common/TraversalClient.h"
    #endif
#endif

// ---------------------------------------------------------------------------
// MARK: - Constants
// ---------------------------------------------------------------------------

NSErrorDomain const PVDolphinNetplayErrorDomain = @"com.provenance.dolphin.netplay";

/// Dolphin's public STUN / traversal relay server.
static NSString * const kDolphinTraversalHost = @"stun.dolphin-emu.org";
static const uint16_t    kDolphinTraversalPort = 6262;

/// Default direct-connect port when the caller passes 0.
static const uint16_t    kDolphinNetplayDefaultPort = 2626;

// ---------------------------------------------------------------------------
// MARK: - C++ wrapper boxes
//
// ObjC wrapper objects let us store unique_ptr<T> via the ObjC
// associated-objects API without unsafe pointer casts across the ARC boundary.
// Only compiled when the Dolphin headers are available.
// ---------------------------------------------------------------------------

#if HAVE_DOLPHIN_NETPLAY

@interface _PVDolphinNetplayServerBox : NSObject {
@public
    std::unique_ptr<NetPlay::NetPlayServer> server;
}
@end
@implementation _PVDolphinNetplayServerBox @end

@interface _PVDolphinNetplayClientBox : NSObject {
@public
    std::unique_ptr<NetPlay::NetPlayClient> client;
}
@end
@implementation _PVDolphinNetplayClientBox @end

/// Minimal no-op NetPlayUI that silences the pure-virtual callbacks Dolphin
/// expects from the host application UI.
class PVDolphinNetPlayUI : public NetPlay::NetPlayUI {
public:
    void BootGame(const std::string&, std::unique_ptr<BootParameters>) override {}
    void StopGame() override {}
    bool IsHosting() const override { return false; }
    void Update() override {}
    void AppendChat(const std::string&) override {}
    void OnMsgChangeGame(const NetPlay::SyncIdentifier&, const std::string&) override {}
    void OnMsgStartGame() override {}
    void OnMsgStopGame() override {}
    void OnMsgPowerButton() override {}
    void OnPlayerConnect(const std::string&) override {}
    void OnPlayerDisconnect(const std::string&) override {}
    void OnPadBufferChanged(u32) override {}
    void OnHostInputAuthorityChanged(bool) override {}
    void OnDesync(u32, const std::string&) override {}
    void OnConnectionLost() override {}
    void OnConnectionError(const std::string&) override {}
    void OnTraversalError(NetPlay::TraversalClient::FailureReason) override {}
    void OnTraversalStateChanged(NetPlay::TraversalClient::State) override {}
    void OnGameStartAborted() override {}
    void OnGolferChanged(bool, const std::string&) override {}
    bool IsRecording() const override { return false; }
};

/// Shared no-op UI instance (Dolphin only needs a non-null pointer; all
/// callbacks are intentionally empty — Provenance drives state via polling).
static PVDolphinNetPlayUI s_netplayUI;

#endif // HAVE_DOLPHIN_NETPLAY

// ---------------------------------------------------------------------------
// MARK: - Associated-object keys
// ---------------------------------------------------------------------------

static const char kServerBoxKey = 0;
static const char kClientBoxKey = 0;

// ---------------------------------------------------------------------------
// MARK: - Implementation
// ---------------------------------------------------------------------------

@implementation PVDolphinCoreBridge (Netplay)

// MARK: Properties

- (BOOL)dolphinNetplaySupported {
#if HAVE_DOLPHIN_NETPLAY
    return YES;
#else
    return NO;
#endif
}

- (PVDolphinNetplayStatus)dolphinNetplayStatus {
#if HAVE_DOLPHIN_NETPLAY
    // A live client connection takes precedence.
    _PVDolphinNetplayClientBox *cb =
        objc_getAssociatedObject(self, &kClientBoxKey);
    if (cb != nil && cb->client != nullptr && cb->client->IsConnected()) {
        return PVDolphinNetplayStatusConnected;
    }
    // Fall back to hosting state.
    _PVDolphinNetplayServerBox *sb =
        objc_getAssociatedObject(self, &kServerBoxKey);
    if (sb != nil && sb->server != nullptr) {
        return PVDolphinNetplayStatusHosting;
    }
#endif
    return PVDolphinNetplayStatusIdle;
}

- (nullable NSString *)dolphinTraversalCode {
#if HAVE_DOLPHIN_NETPLAY
    _PVDolphinNetplayServerBox *sb =
        objc_getAssociatedObject(self, &kServerBoxKey);
    if (sb != nil && sb->server != nullptr) {
        // NetPlayServer::GetInterfaceListToSend() provides the traversal code
        // as a string on builds that use the traversal client.  The exact API
        // differs between Dolphin revisions; adjust if needed.
        return nil; // TODO: query sb->server->GetTraversalCode()
    }
#endif
    return nil;
}

// MARK: - Host

- (BOOL)startNetplayHostOnPort:(uint16_t)port
                      password:(nullable NSString *)password
                    maxPlayers:(NSInteger)maxPlayers
                         error:(NSError *_Nullable __autoreleasing *_Nullable)error {
#if HAVE_DOLPHIN_NETPLAY
    if (self.dolphinNetplayStatus != PVDolphinNetplayStatusIdle) {
        if (error) {
            *error = [NSError errorWithDomain:PVDolphinNetplayErrorDomain
                                         code:PVDolphinNetplayErrorAlreadyActive
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"A Dolphin netplay session is already active."}];
        }
        return NO;
    }

    uint16_t resolvedPort = port > 0 ? port : kDolphinNetplayDefaultPort;

    // Direct-connect (no STUN relay) traversal config.
    NetPlay::NetTraversalConfig traversalConfig{
        .use_traversal  = false,
        .traversal_host = "",
        .traversal_port = 0,
    };

    DLOG(@"[Dolphin Netplay] Starting server on port %u, maxPlayers=%ld",
         resolvedPort, (long)maxPlayers);

    @try {
        auto server = std::make_unique<NetPlay::NetPlayServer>(
            resolvedPort,
            /* forward_port */ false,
            &s_netplayUI,
            traversalConfig
        );

        if (password.length > 0) {
            server->SetPassword(std::string(password.UTF8String));
        }

        // maxPlayers: NetPlayServer does not expose a SetMaxPlayers() in the
        // dolphin-ios revision currently in use.  The value is accepted and
        // propagated to the session model for UI display, but is not enforced
        // by the server.  Wire this once the API is confirmed upstream.
        if (maxPlayers > 0) {
            DLOG(@"[Dolphin Netplay] maxPlayers=%ld requested but not yet "
                 "enforced by NetPlayServer (pending API confirmation).", (long)maxPlayers);
        }
        (void)maxPlayers;

        _PVDolphinNetplayServerBox *sb = [_PVDolphinNetplayServerBox new];
        sb->server = std::move(server);
        objc_setAssociatedObject(self, &kServerBoxKey, sb, OBJC_ASSOCIATION_RETAIN);
    } @catch (NSException *ex) {
        ELOG(@"[Dolphin Netplay] Exception starting server: %@", ex);
        if (error) {
            *error = [NSError errorWithDomain:PVDolphinNetplayErrorDomain
                                         code:PVDolphinNetplayErrorConnectFailed
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    ex.reason ?: @"Unknown error starting server."}];
        }
        return NO;
    }

    // After starting the server, connect locally as the first player.
    NSError *clientError = nil;
    BOOL clientOK = [self joinNetplayHost:@"127.0.0.1"
                                     port:resolvedPort
                            traversalCode:nil
                                 password:password
                                    error:&clientError];
    if (!clientOK) {
        // Tear down the server if we cannot connect locally.
        _PVDolphinNetplayServerBox *sb = objc_getAssociatedObject(self, &kServerBoxKey);
        if (sb != nil) {
            sb->server.reset();
            objc_setAssociatedObject(self, &kServerBoxKey, nil, OBJC_ASSOCIATION_RETAIN);
        }
        if (error) {
            *error = clientError;
        }
        return NO;
    }

    return YES;

#else // !HAVE_DOLPHIN_NETPLAY
    if (error) {
        *error = [NSError errorWithDomain:PVDolphinNetplayErrorDomain
                                     code:PVDolphinNetplayErrorUnsupported
                                 userInfo:@{NSLocalizedDescriptionKey:
                                                @"Dolphin netplay is not available. "
                                                 "Ensure the dolphin-ios submodule is initialised."}];
    }
    return NO;
#endif
}

// MARK: - Join

- (BOOL)joinNetplayHost:(NSString *)host
                   port:(uint16_t)port
          traversalCode:(nullable NSString *)traversalCode
               password:(nullable NSString *)password
                  error:(NSError *_Nullable __autoreleasing *_Nullable)error {
#if HAVE_DOLPHIN_NETPLAY
    // Guard against overwriting an active session without proper teardown.
    // We check for a non-null client pointer (not just IsConnected) so that an
    // in-progress connection attempt is also rejected; the host path skips this
    // guard because it starts with no client box set.
    _PVDolphinNetplayClientBox *existingCB =
        objc_getAssociatedObject(self, &kClientBoxKey);
    if (existingCB != nil && existingCB->client != nullptr) {
        if (error) {
            *error = [NSError errorWithDomain:PVDolphinNetplayErrorDomain
                                         code:PVDolphinNetplayErrorAlreadyActive
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"A Dolphin netplay client session is already active."}];
        }
        return NO;
    }

    BOOL usingTraversal = traversalCode.length > 0;
    if (!usingTraversal && host.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:PVDolphinNetplayErrorDomain
                                         code:PVDolphinNetplayErrorInvalidSettings
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    @"Either a host address or traversal code must be provided."}];
        }
        return NO;
    }

    uint16_t resolvedPort = port > 0 ? port : kDolphinNetplayDefaultPort;

    NetPlay::NetTraversalConfig traversalConfig;
    std::string connectAddress;

    if (usingTraversal) {
        traversalConfig.use_traversal  = true;
        traversalConfig.traversal_host = std::string(kDolphinTraversalHost.UTF8String);
        traversalConfig.traversal_port = kDolphinTraversalPort;
        connectAddress = std::string(traversalCode.UTF8String);
        DLOG(@"[Dolphin Netplay] Connecting via traversal code: %@", traversalCode);
    } else {
        traversalConfig.use_traversal  = false;
        traversalConfig.traversal_host = "";
        traversalConfig.traversal_port = 0;
        connectAddress = std::string(host.UTF8String);
        DLOG(@"[Dolphin Netplay] Connecting directly to %@:%u", host, resolvedPort);
    }

    @try {
        // NetPlayClient constructor (Dolphin 5.x / dolphin-ios):
        //   NetPlayClient(address, port, dialog, player_name, traversal_config)
        // If your dolphin-ios revision uses NetPlayClient::Create() (static factory),
        // replace the constructor call with:
        //   auto client = NetPlay::NetPlayClient::Create(connectAddress, resolvedPort,
        //                                               &s_netplayUI, "", traversalConfig);
        auto client = std::make_unique<NetPlay::NetPlayClient>(
            connectAddress,
            resolvedPort,
            &s_netplayUI,
            /* player_name */ "",
            traversalConfig
        );

        // Client-side password: Dolphin's NetPlayClient does not expose a
        // SetPassword() method in the dolphin-ios revision currently in use.
        // Password verification happens on the server side.  Log a warning so
        // callers know the argument is not yet applied; update when the API is
        // confirmed (search for NetPlayClient::SetPassword in the upstream).
        if (password.length > 0) {
            WLOG(@"[Dolphin Netplay] Password supplied to joinNetplayHost but "
                 "client-side password auth is not yet wired. "
                 "Join will succeed only if the server has no password set.");
        }

        _PVDolphinNetplayClientBox *cb = [_PVDolphinNetplayClientBox new];
        cb->client = std::move(client);
        objc_setAssociatedObject(self, &kClientBoxKey, cb, OBJC_ASSOCIATION_RETAIN);
    } @catch (NSException *ex) {
        ELOG(@"[Dolphin Netplay] Exception during connect: %@", ex);
        if (error) {
            *error = [NSError errorWithDomain:PVDolphinNetplayErrorDomain
                                         code:PVDolphinNetplayErrorConnectFailed
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    ex.reason ?: @"Unknown error during connect."}];
        }
        return NO;
    }

    return YES;

#else // !HAVE_DOLPHIN_NETPLAY
    if (error) {
        *error = [NSError errorWithDomain:PVDolphinNetplayErrorDomain
                                     code:PVDolphinNetplayErrorUnsupported
                                 userInfo:@{NSLocalizedDescriptionKey:
                                                @"Dolphin netplay is not available. "
                                                 "Ensure the dolphin-ios submodule is initialised."}];
    }
    return NO;
#endif
}

// MARK: - Stop

- (void)stopNetplay {
    DLOG(@"[Dolphin Netplay] Stopping session.");
#if HAVE_DOLPHIN_NETPLAY
    // Tear down client first so the server doesn't block on pending connections.
    _PVDolphinNetplayClientBox *cb = objc_getAssociatedObject(self, &kClientBoxKey);
    if (cb != nil) {
        cb->client.reset();
        objc_setAssociatedObject(self, &kClientBoxKey, nil, OBJC_ASSOCIATION_RETAIN);
    }
    _PVDolphinNetplayServerBox *sb = objc_getAssociatedObject(self, &kServerBoxKey);
    if (sb != nil) {
        sb->server.reset();
        objc_setAssociatedObject(self, &kServerBoxKey, nil, OBJC_ASSOCIATION_RETAIN);
    }
#endif
}

@end
