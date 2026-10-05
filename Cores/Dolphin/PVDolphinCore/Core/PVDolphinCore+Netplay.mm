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
//  full implementation is compiled in. The NetPlay, SFML, enet and UICommon
//  symbols all come from PVlibDolphin.xcframework; nothing extra is linked.
//
//  Threading: every NetPlayUI callback runs on one of Dolphin's netplay
//  threads (the client's, the server's, or the traversal client's). They
//  never take @synchronized(self): stopNetplay holds that lock only to detach
//  the session, then joins those threads outside it.
//

#import "PVDolphinCore+Netplay.h"
#import <PVLogging/PVLoggingObjC.h>
@import PVSettings;
#import <objc/runtime.h>

// ---------------------------------------------------------------------------
// MARK: - Dolphin C++ netplay API
//
//   Source/Core/Core/NetPlayClient.h  →  NetPlay::NetPlayClient, NetPlay::NetPlayUI
//   Source/Core/Core/NetPlayServer.h  →  NetPlay::NetPlayServer
//   Source/Core/Common/TraversalClient.h → Common::g_TraversalClient
// ---------------------------------------------------------------------------

#if __has_include("Core/NetPlayClient.h") && __has_include(<SFML/Network/Packet.hpp>) && __has_include(<enet/enet.h>)
    #define HAVE_DOLPHIN_NETPLAY 1
    #include <algorithm>
    #include <atomic>
    #include <memory>
    #include <mutex>
    #include <optional>
    #include <span>
    #include <string>
    #include <vector>

    #include "Common/Config/Config.h"
    #include "Common/TraversalClient.h"
    #include "Core/Boot/Boot.h"
    #include "Core/Config/NetplaySettings.h"
    #include "Core/Core.h"
    #include "Core/IOS/FS/FileSystem.h"
    #include "Core/NetPlayClient.h"
    #include "Core/NetPlayServer.h"
    #include "Core/System.h"
    #include "UICommon/GameFile.h"
    #include "UICommon/UICommon.h"
#else
    #define HAVE_DOLPHIN_NETPLAY 0
#endif

// ---------------------------------------------------------------------------
// MARK: - Constants
// ---------------------------------------------------------------------------

NSErrorDomain const PVDolphinNetplayErrorDomain = @"com.provenance.dolphin.netplay";

#if HAVE_DOLPHIN_NETPLAY

/// Default direct-connect port when the caller passes 0.
static const uint16_t kDolphinNetplayDefaultPort = 2626;

/// Largest pad buffer the bridge accepts.
static const uint32_t kDolphinNetplayMaxBufferSize = 127;

/// How long netplay OSD toasts stay on screen.
static const NSTimeInterval kDolphinNetplayOSDDuration = 4.0;

/// Dolphin's public traversal relay (Config::NETPLAY_TRAVERSAL_* defaults).
static const char *const kDolphinTraversalHost = "stun.dolphin-emu.org";
static const uint16_t kDolphinTraversalPort = 6262;
static const uint16_t kDolphinTraversalPortAlt = 6226;

static NSString *PVNSString(const std::string &s) {
    return [NSString stringWithUTF8String:s.c_str()] ?: @"";
}

static const char *PVTraversalFailureName(Common::TraversalClient::FailureReason reason) {
    switch (reason) {
    case Common::TraversalClient::FailureReason::BadHost:             return "BadHost";
    case Common::TraversalClient::FailureReason::VersionTooOld:       return "VersionTooOld";
    case Common::TraversalClient::FailureReason::ServerForgotAboutUs: return "ServerForgotAboutUs";
    case Common::TraversalClient::FailureReason::SocketSendError:     return "SocketSendError";
    case Common::TraversalClient::FailureReason::ResendTimeout:       return "ResendTimeout";
    }
    return "Unknown";
}

// ---------------------------------------------------------------------------
// MARK: - NetPlayUI
// ---------------------------------------------------------------------------

namespace {

/// Provenance's NetPlay::NetPlayUI. One instance per session, shared by the
/// host's server and client. It outlives both (see PVDolphinNetplaySession).
///
/// The game list and event handler are fixed at construction, so the netplay
/// threads read them without a lock. Everything that changes afterwards is an
/// atomic or guarded by `m_mutex`.
class PVDolphinNetPlayUI final : public NetPlay::NetPlayUI {
public:
    PVDolphinNetPlayUI(std::vector<std::shared_ptr<const UICommon::GameFile>> games,
                       PVDolphinNetplayEventHandler handler,
                       bool hosting)
        : m_games(std::move(games)), m_handler([handler copy]), m_hosting(hosting) {}

    // MARK: Bridge-facing state (called from the bridge's netplay queue)

    /// The local client, once its constructor has returned. Null before that
    /// and during teardown, so callbacks tolerate null.
    void SetClient(NetPlay::NetPlayClient *client) {
        m_client.store(client);
        if (client != nullptr) {
            m_player_count.store(static_cast<int>(client->GetPlayers().size()));
        }
    }

    /// Silences events: tearing the session down makes the server and client
    /// report each other's disconnect, which isn't a lost connection.
    void BeginShutdown() { m_stopping.store(true); }

    std::string HostCode() {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_host_code;
    }

    int PlayerCount() const { return m_player_count.load(); }

    // MARK: NetPlay::NetPlayUI

    // STEP 2 placeholder. The netplay client calls this from StartGame()
    // after NetPlay_Enable; it must reboot the running core with
    // BootManager::BootCore(system, BootParameters::GenerateFromFile(filename,
    // std::move(*boot_session_data)), wsi). OnMsgStartGame does not call
    // client->StartGame yet, so this is never reached.
    void BootGame(const std::string &filename,
                  std::unique_ptr<BootSessionData> boot_session_data) override {
        (void)boot_session_data;
        WLOG(@"[Dolphin Netplay] BootGame(%s) ignored: in-game netplay boot is not wired yet.",
             filename.c_str());
    }

    // STEP 2 placeholder. Must stop the netplay-booted game (Core::Stop)
    // without the full stopEmulation teardown.
    void StopGame() override {
        DLOG(@"[Dolphin Netplay] StopGame ignored: in-game netplay boot is not wired yet.");
    }

    bool IsHosting() const override { return m_hosting; }

    void Update() override {
        if (NetPlay::NetPlayClient *client = m_client.load()) {
            m_player_count.store(static_cast<int>(client->GetPlayers().size()));
        }
    }

    void AppendChat(const std::string &msg) override {
        DLOG(@"[Dolphin Netplay] %s", msg.c_str());
    }

    void OnMsgChangeGame(const NetPlay::SyncIdentifier &sync_identifier,
                         const std::string &netplay_name) override {
        DLOG(@"[Dolphin Netplay] Host selected game: %s", netplay_name.c_str());
        std::lock_guard<std::mutex> lock(m_mutex);
        m_current_game = sync_identifier;
        m_current_game_name = netplay_name;
    }

    // GBA link play (mGBA in Dolphin) isn't supported by Provenance.
    void OnMsgChangeGBARom(int, const NetPlay::GBAConfig &) override {}

    // STEP 2 placeholder. Must look up the selected game with
    // FindGameFile(m_current_game) and call client->StartGame(path), which
    // ends in BootGame above.
    void OnMsgStartGame() override {
        WLOG(@"[Dolphin Netplay] Host started the game, but in-game netplay boot is not wired yet.");
        Toast(@"The host started the game, but Dolphin netplay can't start games in Provenance yet.",
              PVOSDTypeWarning);
    }

    void OnMsgStopGame() override {}

    void OnMsgPowerButton() override {
        if (Core::IsRunning(Core::System::GetInstance())) {
            UICommon::TriggerSTMPowerEvent();
        }
    }

    void OnPlayerConnect(const std::string &player) override {
        ILOG(@"[Dolphin Netplay] %s joined.", player.c_str());
        NSString *name = PVNSString(player);
        Toast([NSString stringWithFormat:@"%@ joined", name], PVOSDTypeInfo);
        Post(PVDolphinNetplayEventPlayersChanged, name);
    }

    void OnPlayerDisconnect(const std::string &player) override {
        ILOG(@"[Dolphin Netplay] %s left.", player.c_str());
        NSString *name = PVNSString(player);
        Toast([NSString stringWithFormat:@"%@ left", name], PVOSDTypeInfo);
        Post(PVDolphinNetplayEventPlayersChanged, name);
    }

    void OnPadBufferChanged(u32 buffer) override {
        DLOG(@"[Dolphin Netplay] Pad buffer is now %u.", buffer);
    }

    void OnHostInputAuthorityChanged(bool enabled) override {
        DLOG(@"[Dolphin Netplay] Host input authority %s.", enabled ? "on" : "off");
    }

    void OnDesync(u32 frame, const std::string &player) override {
        WLOG(@"[Dolphin Netplay] Desync with %s at frame %u.", player.c_str(), frame);
        NSString *message = [NSString stringWithFormat:@"Netplay desync with %@ at frame %u",
                                                       PVNSString(player), frame];
        Toast(message, PVOSDTypeWarning);
        Post(PVDolphinNetplayEventDesync, message);
    }

    void OnConnectionLost() override {
        WLOG(@"[Dolphin Netplay] Connection lost.");
        Toast(@"Netplay connection lost", PVOSDTypeError);
        Post(PVDolphinNetplayEventConnectionLost, nil);
    }

    void OnConnectionError(const std::string &message) override {
        ELOG(@"[Dolphin Netplay] Connection error: %s", message.c_str());
        NSString *text = PVNSString(message);
        Toast([NSString stringWithFormat:@"Netplay: %@", text], PVOSDTypeError);
        Post(PVDolphinNetplayEventConnectionError, text);
    }

    // OnTraversalStateChanged(Failure) always follows and reports it.
    void OnTraversalError(Common::TraversalClient::FailureReason error) override {
        WLOG(@"[Dolphin Netplay] Traversal error: %s", PVTraversalFailureName(error));
    }

    void OnTraversalStateChanged(Common::TraversalClient::State state) override {
        // A traversal client also gets these; only the host has a code to share.
        if (!m_hosting || !Common::g_TraversalClient) {
            return;
        }
        if (state == Common::TraversalClient::State::Connected) {
            const Common::TraversalHostId host_id = Common::g_TraversalClient->GetHostID();
            if (host_id[0] == '\0') {
                return;  // Connected, but the relay hasn't assigned a code yet.
            }
            const auto end = std::find(host_id.begin(), host_id.end(), '\0');
            const std::string code(host_id.begin(), end);
            {
                std::lock_guard<std::mutex> lock(m_mutex);
                m_host_code = code;
            }
            ILOG(@"[Dolphin Netplay] Traversal code: %s", code.c_str());
            Post(PVDolphinNetplayEventTraversalCodeReady, PVNSString(code));
        } else if (state == Common::TraversalClient::State::Failure) {
            const char *reason = PVTraversalFailureName(Common::g_TraversalClient->GetFailureReason());
            {
                std::lock_guard<std::mutex> lock(m_mutex);
                m_host_code.clear();
            }
            ELOG(@"[Dolphin Netplay] Traversal relay failed: %s", reason);
            Toast(@"Couldn't reach the Dolphin traversal server", PVOSDTypeError);
            Post(PVDolphinNetplayEventTraversalFailed, @(reason));
        }
    }

    void OnGameStartAborted() override {
        WLOG(@"[Dolphin Netplay] Game start aborted.");
        Toast(@"Netplay game start was aborted", PVOSDTypeWarning);
    }

    void OnGolferChanged(bool, const std::string &) override {}
    void OnTtlDetermined(u8) override {}

    bool IsRecording() override { return false; }

    // Called by the client (game status) and, on the host, by the server
    // (save sync, region, start). Mirrors DolphinQt / Android: the best
    // CompareSyncIdentifier match among the session's candidate games.
    std::shared_ptr<const UICommon::GameFile>
    FindGameFile(const NetPlay::SyncIdentifier &sync_identifier,
                 NetPlay::SyncIdentifierComparison *found) override {
        NetPlay::SyncIdentifierComparison temp;
        if (found == nullptr) {
            found = &temp;
        }
        *found = NetPlay::SyncIdentifierComparison::DifferentGame;

        std::shared_ptr<const UICommon::GameFile> result;
        for (const auto &game : m_games) {
            const NetPlay::SyncIdentifierComparison cmp = game->CompareSyncIdentifier(sync_identifier);
            if (cmp < *found) {
                *found = cmp;
                result = game;
            }
        }
        return result;
    }

    std::string FindGBARomPath(const std::array<u8, 20> &, std::string_view, int) override {
        return {};
    }

    // Game digest (a host-requested hash check of every player's game).
    void ShowGameDigestDialog(const std::string &title) override {
        DLOG(@"[Dolphin Netplay] Game digest started: %s", title.c_str());
    }
    void SetGameDigestProgress(int, int) override {}
    void SetGameDigestResult(int pid, const std::string &result) override {
        ILOG(@"[Dolphin Netplay] Game digest for player %d: %s", pid, result.c_str());
    }
    void AbortGameDigest() override {}

    // Lobby index; Provenance never registers with it.
    void OnIndexAdded(bool success, std::string error) override {
        if (!success) {
            WLOG(@"[Dolphin Netplay] Index registration failed: %s", error.c_str());
        }
    }
    void OnIndexRefreshFailed(std::string error) override {
        WLOG(@"[Dolphin Netplay] Index refresh failed: %s", error.c_str());
    }

    // Save / code sync progress before a game starts.
    void ShowChunkedProgressDialog(const std::string &title, u64 data_size,
                                   std::span<const int> players) override {
        DLOG(@"[Dolphin Netplay] %s (%llu bytes, %zu players)", title.c_str(),
             static_cast<unsigned long long>(data_size), players.size());
    }
    void HideChunkedProgressDialog() override {}
    void SetChunkedProgress(int, u64) override {}

    // The host's server hands the Wii save sync data to the host's own client.
    void SetHostWiiSyncData(std::vector<u64> titles, std::string redirect_folder) override {
        if (NetPlay::NetPlayClient *client = m_client.load()) {
            client->SetWiiSyncData(nullptr, std::move(titles), std::move(redirect_folder));
        }
    }

private:
    /// Delivers an event on the main queue. Captures copies only: this object
    /// can be destroyed before the block runs.
    void Post(PVDolphinNetplayEvent event, NSString *message) {
        PVDolphinNetplayEventHandler handler = m_handler;
        if (handler == nil || m_stopping.load()) {
            return;
        }
        NSString *text = [message copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(event, text);
        });
    }

    void Toast(NSString *message, PVOSDType type) {
        if (m_stopping.load()) {
            return;
        }
        [PVOSDNotification postMessage:message type:type duration:kDolphinNetplayOSDDuration];
    }

    const std::vector<std::shared_ptr<const UICommon::GameFile>> m_games;
    const PVDolphinNetplayEventHandler m_handler;
    const bool m_hosting;

    std::atomic<NetPlay::NetPlayClient *> m_client{nullptr};
    std::atomic<bool> m_stopping{false};
    std::atomic<int> m_player_count{0};

    std::mutex m_mutex;
    std::string m_host_code;                              // guarded by m_mutex
    std::optional<NetPlay::SyncIdentifier> m_current_game; // guarded by m_mutex; read in step 2
    std::string m_current_game_name;                      // guarded by m_mutex
};

/// One netplay session. The UI must outlive the client and server that hold
/// a pointer to it, so teardown is client → server → UI. Destroying it joins
/// Dolphin's netplay threads: never do that on one of them.
struct PVDolphinNetplaySession {
    std::unique_ptr<PVDolphinNetPlayUI> ui;
    std::unique_ptr<NetPlay::NetPlayServer> server;
    std::unique_ptr<NetPlay::NetPlayClient> client;

    ~PVDolphinNetplaySession() {
        if (ui) {
            ui->BeginShutdown();
            ui->SetClient(nullptr);
        }
        client.reset();
        server.reset();
        ui.reset();
    }
};

}  // namespace

// ---------------------------------------------------------------------------
// MARK: - Session box
//
// Holds the C++ session in an associated object so the category needs no
// ivar in PVDolphinCore.mm.
// ---------------------------------------------------------------------------

@interface _PVDolphinNetplaySessionBox : NSObject {
@public
    std::unique_ptr<PVDolphinNetplaySession> session;
}
@end
@implementation _PVDolphinNetplaySessionBox @end

#endif // HAVE_DOLPHIN_NETPLAY

// ---------------------------------------------------------------------------
// MARK: - Associated-object keys
// ---------------------------------------------------------------------------

// Non-const so each key is a distinct object the compiler can't merge.
static char kSessionBoxKey;
static char kEventHandlerKey;
static char kCandidatePathsKey;

// ---------------------------------------------------------------------------
// MARK: - Implementation
// ---------------------------------------------------------------------------

@implementation PVDolphinCoreBridge (Netplay)

static NSError *PVMakeDolphinNetplayError(PVDolphinNetplayError code, NSString *description) {
    return [NSError errorWithDomain:PVDolphinNetplayErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

// MARK: Properties

- (BOOL)dolphinNetplaySupported {
    return HAVE_DOLPHIN_NETPLAY ? YES : NO;
}

- (nullable PVDolphinNetplayEventHandler)dolphinNetplayEventHandler {
    return objc_getAssociatedObject(self, &kEventHandlerKey);
}

- (void)setDolphinNetplayEventHandler:(nullable PVDolphinNetplayEventHandler)handler {
    objc_setAssociatedObject(self, &kEventHandlerKey, handler, OBJC_ASSOCIATION_COPY);
}

- (nullable NSArray<NSString *> *)dolphinNetplayCandidateGamePaths {
    return objc_getAssociatedObject(self, &kCandidatePathsKey);
}

- (void)setDolphinNetplayCandidateGamePaths:(nullable NSArray<NSString *> *)paths {
    objc_setAssociatedObject(self, &kCandidatePathsKey, paths, OBJC_ASSOCIATION_COPY);
}

#if HAVE_DOLPHIN_NETPLAY

/// The live session, or null. Callers hold @synchronized(self).
- (PVDolphinNetplaySession *)_netplaySessionLocked {
    _PVDolphinNetplaySessionBox *box = objc_getAssociatedObject(self, &kSessionBoxKey);
    return box != nil ? box->session.get() : nullptr;
}

/// The ROM loadFileAtPath: stored. It is an @implementation ivar of
/// PVDolphinCore.mm, which this category can't name directly.
- (nullable NSString *)_netplayLoadedROMPath {
    Ivar ivar = class_getInstanceVariable([PVDolphinCoreBridge class], "_romPath");
    if (ivar == NULL) {
        return nil;
    }
    id value = object_getIvar(self, ivar);
    return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}

/// Opens the loaded ROM and any extra candidates as Dolphin game files. The
/// loaded ROM, if Dolphin can read it, comes first.
- (std::vector<std::shared_ptr<const UICommon::GameFile>>)_netplayCandidateGames {
    NSMutableOrderedSet<NSString *> *paths = [NSMutableOrderedSet orderedSet];
    NSString *loaded = [self _netplayLoadedROMPath];
    if (loaded.length > 0) {
        [paths addObject:loaded];
    }
    for (NSString *path in self.dolphinNetplayCandidateGamePaths ?: @[]) {
        if (path.length > 0) {
            [paths addObject:path];
        }
    }

    std::vector<std::shared_ptr<const UICommon::GameFile>> games;
    for (NSString *path in paths) {
        auto game = std::make_shared<const UICommon::GameFile>(std::string(path.fileSystemRepresentation));
        if (game->IsValid()) {
            games.push_back(std::move(game));
        } else {
            WLOG(@"[Dolphin Netplay] Skipping unreadable game: %@", path);
        }
    }
    return games;
}

- (BOOL)_hasNetplaySession {
    @synchronized (self) {
        return [self _netplaySessionLocked] != nullptr;
    }
}

/// Stores a fully set-up session, unless another one won the race.
- (BOOL)_installNetplaySession:(std::unique_ptr<PVDolphinNetplaySession> &)session
                         error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    @synchronized (self) {
        if ([self _netplaySessionLocked] == nullptr) {
            _PVDolphinNetplaySessionBox *box = [_PVDolphinNetplaySessionBox new];
            box->session = std::move(session);
            objc_setAssociatedObject(self, &kSessionBoxKey, box, OBJC_ASSOCIATION_RETAIN);
            return YES;
        }
    }
    // `session` still owns the loser; its destructor runs outside the lock.
    if (error) {
        *error = PVMakeDolphinNetplayError(PVDolphinNetplayErrorAlreadyActive,
                                       @"A Dolphin netplay session is already active.");
    }
    return NO;
}

#endif // HAVE_DOLPHIN_NETPLAY

- (PVDolphinNetplayStatus)dolphinNetplayStatus {
#if HAVE_DOLPHIN_NETPLAY
    @synchronized (self) {
        PVDolphinNetplaySession *session = [self _netplaySessionLocked];
        if (session == nullptr) {
            return PVDolphinNetplayStatusIdle;
        }
        // The host's own client is always connected, so the server decides.
        if (session->server != nullptr) {
            return PVDolphinNetplayStatusHosting;
        }
        if (session->client != nullptr && session->client->IsConnected()) {
            return PVDolphinNetplayStatusConnected;
        }
    }
#endif
    return PVDolphinNetplayStatusIdle;
}

- (nullable NSString *)dolphinTraversalCode {
#if HAVE_DOLPHIN_NETPLAY
    std::string code;
    @synchronized (self) {
        PVDolphinNetplaySession *session = [self _netplaySessionLocked];
        if (session == nullptr || session->server == nullptr) {
            return nil;
        }
        code = session->ui->HostCode();
    }
    return code.empty() ? nil : PVNSString(code);
#else
    return nil;
#endif
}

- (NSInteger)dolphinNetplayPlayerCount {
#if HAVE_DOLPHIN_NETPLAY
    @synchronized (self) {
        PVDolphinNetplaySession *session = [self _netplaySessionLocked];
        return session != nullptr ? session->ui->PlayerCount() : 0;
    }
#else
    return 0;
#endif
}

// MARK: - Host

- (BOOL)startNetplayHostOnPort:(uint16_t)port
                      password:(nullable NSString *)password
                    maxPlayers:(NSInteger)maxPlayers
                  useTraversal:(BOOL)useTraversal
                         error:(NSError *_Nullable __autoreleasing *_Nullable)error {
#if HAVE_DOLPHIN_NETPLAY
    // Any session counts, even one whose connection already dropped.
    if ([self _hasNetplaySession]) {
        if (error) {
            *error = PVMakeDolphinNetplayError(PVDolphinNetplayErrorAlreadyActive,
                                           @"A Dolphin netplay session is already active.");
        }
        return NO;
    }
    if (password.length > 0) {
        WLOG(@"[Dolphin Netplay] Room passwords aren't supported by this Dolphin revision; ignoring.");
    }
    if (maxPlayers > 0) {
        DLOG(@"[Dolphin Netplay] maxPlayers=%ld isn't enforced by NetPlayServer.", (long)maxPlayers);
    }

    std::vector<std::shared_ptr<const UICommon::GameFile>> games = [self _netplayCandidateGames];
    if (games.empty()) {
        if (error) {
            *error = PVMakeDolphinNetplayError(PVDolphinNetplayErrorInvalidSettings,
                                           @"Dolphin netplay can't read the loaded game.");
        }
        return NO;
    }
    // The loaded ROM is first; it is the game the room plays.
    const std::shared_ptr<const UICommon::GameFile> game = games.front();

    // With traversal, port 0 lets the OS pick: clients reach the host by code.
    const uint16_t listenPort = port > 0 ? port : (useTraversal ? 0 : kDolphinNetplayDefaultPort);
    std::string playerName{[PVSettingsWrapper.resolvedPlayerUsername UTF8String] ?: ""};

    DLOG(@"[Dolphin Netplay] Hosting on port %u (traversal %s).", listenPort, useTraversal ? "on" : "off");

    auto session = std::make_unique<PVDolphinNetplaySession>();
    try {
        session->ui = std::make_unique<PVDolphinNetPlayUI>(std::move(games),
                                                           self.dolphinNetplayEventHandler,
                                                           /* hosting */ true);
        session->server = std::make_unique<NetPlay::NetPlayServer>(
            listenPort,
            /* forward_port (UPnP) */ false,
            session->ui.get(),
            NetPlay::NetTraversalConfig{static_cast<bool>(useTraversal), kDolphinTraversalHost,
                                        kDolphinTraversalPort, kDolphinTraversalPortAlt});
        if (!session->server->is_connected) {
            if (error) {
                NSString *reason = useTraversal
                    ? @"Couldn't start the Dolphin netplay server or reach the traversal server."
                    : [NSString stringWithFormat:@"Couldn't listen on port %u.", listenPort];
                *error = PVMakeDolphinNetplayError(PVDolphinNetplayErrorConnectFailed, reason);
            }
            return NO;
        }

        // Select the game before joining, as DolphinQt does; the server sends
        // it to each player as they connect.
        const std::string gameName = game->GetLongName().empty() ? game->GetFileName()
                                                                   : game->GetLongName();
        session->server->ChangeGame(game->GetSyncIdentifier(), gameName);

        // The host plays through its own client on loopback.
        session->client = std::make_unique<NetPlay::NetPlayClient>(
            "127.0.0.1",
            session->server->GetPort(),
            session->ui.get(),
            playerName,
            NetPlay::NetTraversalConfig{false, kDolphinTraversalHost, kDolphinTraversalPort});
        if (!session->client->IsConnected()) {
            if (error) {
                *error = PVMakeDolphinNetplayError(PVDolphinNetplayErrorConnectFailed,
                                               @"Couldn't join the local Dolphin netplay server.");
            }
            return NO;
        }
        session->ui->SetClient(session->client.get());
    } catch (const std::exception &cppEx) {
        ELOG(@"[Dolphin Netplay] C++ exception starting server: %s", cppEx.what());
        if (error) {
            *error = PVMakeDolphinNetplayError(PVDolphinNetplayErrorConnectFailed,
                                           [NSString stringWithUTF8String:cppEx.what()] ?: @"Unknown error starting server.");
        }
        return NO;
    } catch (...) {
        ELOG(@"[Dolphin Netplay] Unknown C++ exception starting server.");
        if (error) {
            *error = PVMakeDolphinNetplayError(PVDolphinNetplayErrorConnectFailed, @"Unknown error starting server.");
        }
        return NO;
    }

    return [self _installNetplaySession:session error:error];

#else // !HAVE_DOLPHIN_NETPLAY
    (void)port; (void)password; (void)maxPlayers; (void)useTraversal;
    if (error) {
        *error = PVMakeDolphinNetplayError(PVDolphinNetplayErrorUnsupported,
                                       @"Dolphin netplay is not available. Ensure the dolphin-ios submodule is initialised.");
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
    // Any session counts, even one whose connection already dropped.
    if ([self _hasNetplaySession]) {
        if (error) {
            *error = PVMakeDolphinNetplayError(PVDolphinNetplayErrorAlreadyActive,
                                           @"A Dolphin netplay session is already active.");
        }
        return NO;
    }

    const BOOL usingTraversal = traversalCode.length > 0;
    if (!usingTraversal && host.length == 0) {
        if (error) {
            *error = PVMakeDolphinNetplayError(PVDolphinNetplayErrorInvalidSettings,
                                           @"Either a host address or traversal code must be provided.");
        }
        return NO;
    }
    if (password.length > 0) {
        WLOG(@"[Dolphin Netplay] Room passwords aren't supported by this Dolphin revision; ignoring.");
    }

    const uint16_t resolvedPort = port > 0 ? port : kDolphinNetplayDefaultPort;
    const std::string connectAddress{usingTraversal ? traversalCode.UTF8String : host.UTF8String};
    std::string playerName{[PVSettingsWrapper.resolvedPlayerUsername UTF8String] ?: ""};

    if (usingTraversal) {
        DLOG(@"[Dolphin Netplay] Joining by traversal code %@", traversalCode);
    } else {
        DLOG(@"[Dolphin Netplay] Joining %@:%u", host, resolvedPort);
    }

    auto session = std::make_unique<PVDolphinNetplaySession>();
    try {
        session->ui = std::make_unique<PVDolphinNetPlayUI>([self _netplayCandidateGames],
                                                           self.dolphinNetplayEventHandler,
                                                           /* hosting */ false);
        // Blocks until connected or failed (OnConnectionError reports why).
        session->client = std::make_unique<NetPlay::NetPlayClient>(
            connectAddress,
            resolvedPort,
            session->ui.get(),
            playerName,
            NetPlay::NetTraversalConfig{static_cast<bool>(usingTraversal), kDolphinTraversalHost,
                                        kDolphinTraversalPort, kDolphinTraversalPortAlt});
        if (!session->client->IsConnected()) {
            if (error) {
                *error = PVMakeDolphinNetplayError(PVDolphinNetplayErrorConnectFailed,
                                               @"Couldn't connect to the Dolphin netplay host.");
            }
            return NO;
        }
        session->ui->SetClient(session->client.get());
    } catch (const std::exception &cppEx) {
        ELOG(@"[Dolphin Netplay] C++ exception during connect: %s", cppEx.what());
        if (error) {
            *error = PVMakeDolphinNetplayError(PVDolphinNetplayErrorConnectFailed,
                                           [NSString stringWithUTF8String:cppEx.what()] ?: @"Unknown error during connect.");
        }
        return NO;
    } catch (...) {
        ELOG(@"[Dolphin Netplay] Unknown C++ exception during connect.");
        if (error) {
            *error = PVMakeDolphinNetplayError(PVDolphinNetplayErrorConnectFailed, @"Unknown error during connect.");
        }
        return NO;
    }

    return [self _installNetplaySession:session error:error];

#else // !HAVE_DOLPHIN_NETPLAY
    (void)host; (void)port; (void)traversalCode; (void)password;
    if (error) {
        *error = PVMakeDolphinNetplayError(PVDolphinNetplayErrorUnsupported,
                                       @"Dolphin netplay is not available. Ensure the dolphin-ios submodule is initialised.");
    }
    return NO;
#endif
}

// MARK: - Input buffer / frame delay

- (void)setNetplayInputBufferSize:(uint32_t)bufferSize {
#if HAVE_DOLPHIN_NETPLAY
    const uint32_t clamped = std::min(bufferSize, kDolphinNetplayMaxBufferSize);
    BOOL hosting = NO;
    @synchronized (self) {
        PVDolphinNetplaySession *session = [self _netplaySessionLocked];
        if (session != nullptr && session->server != nullptr) {
            hosting = YES;
            // Sends the new buffer to every client.
            session->server->AdjustPadBufferSize(clamped);
        }
    }
    DLOG(@"[Dolphin Netplay] %s pad buffer: %u (requested %u)",
         hosting ? "Host" : "Client", clamped, bufferSize);
    if (hosting) {
        Config::SetCurrent(Config::NETPLAY_BUFFER_SIZE, clamped);
    } else {
        Config::SetCurrent(Config::NETPLAY_CLIENT_BUFFER_SIZE, clamped);
    }
#else
    (void)bufferSize;
#endif
}

// MARK: - Stop

- (void)stopNetplay {
    DLOG(@"[Dolphin Netplay] Stopping session.");
#if HAVE_DOLPHIN_NETPLAY
    std::unique_ptr<PVDolphinNetplaySession> session;
    @synchronized (self) {
        _PVDolphinNetplaySessionBox *box = objc_getAssociatedObject(self, &kSessionBoxKey);
        if (box != nil) {
            session = std::move(box->session);
            objc_setAssociatedObject(self, &kSessionBoxKey, nil, OBJC_ASSOCIATION_RETAIN);
        }
    }
    // Joins the netplay threads, outside the lock their callbacks never take.
    session.reset();
#endif
}

@end
