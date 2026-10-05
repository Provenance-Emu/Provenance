//
//  MednafenGameCoreBridge+Netplay.mm
//  PVMednafen
//
//  Created by Joseph Mattiello on 3/21/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Mednafen netplay client glue plus the embedded mednafen-server (host).
//
//  Mednafen's netplay state (the Connection in netplay.cpp) is read every
//  frame by Netplay_Update on the emulation thread, and RecvData blocks there
//  until the frame's input arrives. So connect/disconnect are never called
//  from another thread: requests go into a mailbox the emulation thread empties
//  at the start of each frame (-netplayWillEmulateFrame). A frame blocked in
//  RecvData is aborted through MDFND_CheckNeedExit.
//
//  The driver callbacks Mednafen calls (MDFND_NetplayText,
//  MDFND_NetplaySetHints, MDFND_CheckNeedExit) live here too.
//

#import <MednafenGameCoreBridge/MednafenGameCoreBridge+Netplay.h>

#include <mednafen/types.h>
#include <mednafen/mednafen.h>
#include <mednafen/netplay-driver.h>
@import mednafen;
@import PVLoggingObjC;
@import PVCoreObjCBridge;

#include <mednafen_server.h>

#include <pthread.h>
#include <atomic>
#include <chrono>
#include <exception>
#include <mutex>
#include <string>
#include <system_error>
#include <thread>

NSErrorDomain const PVMednafenNetplayErrorDomain = @"com.provenance.mednafen.netplay";

namespace {

// MARK: - Constants

/// Seconds a new connection has to log in before the server drops it.
constexpr int32_t kServerConnectTimeoutSeconds = 5;
/// Seconds without input before the server drops a player. Mednafen's default
/// is 30; a host sitting in the pause menu sends nothing, so allow longer.
constexpr int32_t kServerIdleTimeoutSeconds = 120;
/// Waiting this long for netplay data with no progress gives up and
/// disconnects (host app suspended, Wi-Fi gone without a TCP reset). Without
/// it the emulation thread would block forever and quit would deadlock.
constexpr int64_t kNetplayStallTimeoutMS = 10 * 1000;
/// While a pause is waiting for the frame to finish (holding the main thread),
/// give up on netplay data much sooner.
constexpr int64_t kNetplayPauseWaitTimeoutMS = 1000;
/// OSD durations, seconds.
constexpr NSTimeInterval kNetplayTextOSDDuration = 3.0;
constexpr NSTimeInterval kNetplayErrorOSDDuration = 5.0;
/// Name of the server thread, for debuggers and crash logs.
constexpr const char *kServerThreadName = "com.provenance.mednafen.netplay-server";

// MARK: - Client state

struct PendingConnect {
    std::string host;
    uint16_t port = 0;
    std::string nickname;
    std::string password;
    bool spectator = false;
};

/// Requests from any thread, taken by the emulation thread each frame.
std::mutex g_mailboxMutex;
bool g_pendingDisconnect = false;   // guarded by g_mailboxMutex
bool g_hasPendingConnect = false;   // guarded by g_mailboxMutex
PendingConnect g_pendingConnect;    // guarded by g_mailboxMutex

/// PVMednafenNetplayStatus, readable from any thread.
std::atomic<int> g_status(PVMednafenNetplayStatusIdle);
/// Makes MDFND_CheckNeedExit abort a frame blocked in RecvData/SendData:
/// a user disconnect (cleared once the emulation thread has carried it out)…
std::atomic<bool> g_needExit(false);
/// …and core teardown (cleared only when teardown is complete).
std::atomic<bool> g_teardown(false);
/// A pause is waiting for the current frame (see -netplayWillSetPause:).
std::atomic<bool> g_pauseRequested(false);
/// Monotonic ms of the last netplay progress (frame start, or data received);
/// 0 between frames.
std::atomic<int64_t> g_lastProgressMS(0);
/// Mednafen's "more input already waiting" hint: we are behind the server.
std::atomic<bool> g_behind(false);

std::mutex g_messageMutex;
std::string g_lastMessage;          // guarded by g_messageMutex

// Emulation-thread only (or teardown, after that thread has stopped).
bool g_localDisconnect = false;     // inside our own MDFNI_NetplayDisconnect call
bool g_connectCallActive = false;   // inside our own MDFNI_NetplayConnect call
bool g_connectCallSawText = false;
bool g_connectCallFailed = false;
/// Why MDFND_CheckNeedExit gave up on its own, if it did.
enum class AbortReason { none, stall, pause };
AbortReason g_abortReason = AbortReason::none;
/// The last text the server sent this session. A refusal ("Invalid server
/// password.", "Sorry, game is full.", host-first) arrives this way just
/// before the server closes the connection, so it is the real reason.
std::string g_lastServerText;
/// netplay.cpp prefixes text the server sent (MDFNNPCMD_SERVERTEXT) with this.
constexpr const char *kServerTextPrefix = "** ";
/// The emulation loop's frame pacing is switched off to catch up.
bool g_catchingUp = false;

// MARK: - Server state

std::mutex g_serverMutex;
std::thread g_serverThread;         // guarded by g_serverMutex

int64_t NowMS() {
    using namespace std::chrono;
    return duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count();
}

NSString *StringFromCString(const char *text) {
    if (!text) { return @""; }
    return [NSString stringWithUTF8String:text] ?: @"";
}

void SetLastMessage(const std::string &message) {
    std::lock_guard<std::mutex> lock(g_messageMutex);
    g_lastMessage = message;
}

std::string LastMessage() {
    std::lock_guard<std::mutex> lock(g_messageMutex);
    return g_lastMessage;
}

bool DisconnectPending() {
    std::lock_guard<std::mutex> lock(g_mailboxMutex);
    return g_pendingDisconnect;
}

/// Connecting/Connected → Disconnected, unless someone already moved it on
/// (a user disconnect sets Idle).
void MarkConnectionLost(const std::string &reason) {
    int status = g_status.load();
    if (status != PVMednafenNetplayStatusConnecting && status != PVMednafenNetplayStatusConnected) {
        return;
    }
    if (!g_status.compare_exchange_strong(status, PVMednafenNetplayStatusDisconnected)) {
        return;
    }
    if (!reason.empty()) {
        SetLastMessage(reason);
    }
    NSString *detail = StringFromCString(LastMessage().c_str());
    ELOG(@"[Mednafen Netplay] Connection lost: %@", detail);
    NSString *message = detail.length > 0
        ? [NSString stringWithFormat:@"Netplay disconnected: %@", detail]
        : @"Netplay disconnected.";
    [PVOSDNotification postMessage:message type:PVOSDTypeError duration:kNetplayErrorOSDDuration];
}

/// Emulation thread: apply the settings Mednafen reads and start connecting.
/// MDFNI_NetplayConnect reports its own failures through NetError
/// (MDFND_NetplayText, then a disconnect) instead of throwing.
void PerformConnect(const PendingConnect &request) {
    g_connectCallActive = true;
    g_connectCallSawText = false;
    g_connectCallFailed = false;
    g_lastServerText.clear();
    std::string failure;

    try {
        Mednafen::MDFNI_SetSetting("netplay.host", request.host);
        Mednafen::MDFNI_SetSettingUI("netplay.port", request.port);
        Mednafen::MDFNI_SetSetting("netplay.nick", request.nickname);
        Mednafen::MDFNI_SetSetting("netplay.password", request.password);
        // The game key is hashed into the game ID, so every player would need
        // the same one; the server password already gates who can join.
        Mednafen::MDFNI_SetSetting("netplay.gamekey", std::string());
        Mednafen::MDFNI_SetSettingUI("netplay.localplayers", request.spectator ? 0 : 1);
        Mednafen::MDFNI_NetplayConnect();
    } catch (std::exception &e) {
        failure = e.what();
        g_connectCallFailed = true;
    } catch (...) {
        failure = "Unknown error while connecting.";
        g_connectCallFailed = true;
    }
    g_connectCallActive = false;

    if (g_connectCallFailed) {
        MarkConnectionLost(failure);
    }
}

void ServerLog(const char *line) {
    ILOG(@"[mednafen-server] %s", line);
}

NSString *ServerFailureDescription(MednafenServerResult result, uint16_t port) {
    switch (result) {
        case MednafenServerResultAlreadyRunning:
            return @"The netplay server is already running.";
        case MednafenServerResultInvalidConfig:
            return @"Invalid netplay server settings.";
        case MednafenServerResultOutOfMemory:
            return @"Not enough memory to start the netplay server.";
        case MednafenServerResultBindFailed:
            return [NSString stringWithFormat:@"Port %u is in use or unavailable.", port];
        case MednafenServerResultSocketFailed:
        case MednafenServerResultListenFailed:
        default:
            return [NSString stringWithFormat:@"Could not listen on port %u.", port];
    }
}

} // namespace

// MARK: - Mednafen driver callbacks

namespace Mednafen {

void MDFND_NetplayText(const char *text, bool NetEcho) {
    NSString *message = StringFromCString(text);
    ILOG(@"[Mednafen Netplay] %@", message);

    if (g_connectCallActive) {
        g_connectCallSawText = true;
    }
    const std::string line = text ? text : "";
    const std::string prefix = kServerTextPrefix;
    if (line.compare(0, prefix.size(), prefix) == 0) {
        g_lastServerText = line.substr(prefix.size());
    }
    // "Mednafen exit pending." after our own abort is noise, not news.
    if (g_needExit.load() || g_teardown.load() || g_abortReason != AbortReason::none || message.length == 0) {
        return;
    }
    // "*** Connecting…", "*** Disconnected" and the like are progress, not a
    // reason; keep the last error (NetError's text) for the lost-connection message.
    if (line.compare(0, 4, "*** ") != 0) {
        SetLastMessage(line);
    }
    [PVOSDNotification postMessage:message type:PVOSDTypeInfo duration:kNetplayTextOSDDuration];
}

void MDFND_NetplaySetHints(bool active, bool behind, uint32 local_players_mask) {
    if (active) {
        // NetplayStart (login sent) and every received frame: progress.
        g_lastProgressMS.store(NowMS());
        g_behind.store(behind);
        // Ignore a session that is being torn down.
        if (g_needExit.load() || g_teardown.load() || DisconnectPending()) {
            return;
        }
        int expected = PVMednafenNetplayStatusConnecting;
        g_status.compare_exchange_strong(expected, PVMednafenNetplayStatusConnected);
        return;
    }

    // MDFNI_NetplayDisconnect always ends here.
    if (g_connectCallActive) {
        // MDFNI_NetplayConnect disconnects first (silently); a disconnect
        // after it has printed "Connecting to…" is NetError: the connect failed.
        if (g_connectCallSawText) {
            g_connectCallFailed = true;
        }
        return;
    }
    g_behind.store(false);
    if (g_localDisconnect || g_needExit.load() || g_teardown.load() || DisconnectPending()) {
        return;
    }
    const AbortReason abortReason = g_abortReason;
    g_abortReason = AbortReason::none;
    switch (abortReason) {
        case AbortReason::stall:
            MarkConnectionLost("No data from the netplay server for "
                               + std::to_string(kNetplayStallTimeoutMS / 1000) + " seconds.");
            return;
        case AbortReason::pause:
            MarkConnectionLost("The game was paused while waiting for other players.");
            return;
        case AbortReason::none:
            break;
    }
    // If the server said why it closed the connection, that's the reason.
    MarkConnectionLost(g_lastServerText);
}

// Called by netplay.cpp's SendData/RecvData while waiting on the network.
bool MDFND_CheckNeedExit(void) {
    if (g_needExit.load() || g_teardown.load()) {
        return true;
    }
    const int64_t lastProgress = g_lastProgressMS.load();
    if (lastProgress == 0) {
        return false;
    }
    const int64_t waited = NowMS() - lastProgress;
    if (g_pauseRequested.load() && waited > kNetplayPauseWaitTimeoutMS) {
        g_abortReason = AbortReason::pause;
        return true;
    }
    if (waited > kNetplayStallTimeoutMS) {
        g_abortReason = AbortReason::stall;
        return true;
    }
    return false;
}

} // namespace Mednafen

// MARK: - Bridge

@implementation MednafenGameCoreBridge (Netplay)

- (PVMednafenNetplayStatus)mednafenNetplayStatus {
    return (PVMednafenNetplayStatus)g_status.load();
}

- (nullable NSString *)mednafenNetplayLastMessage {
    const std::string message = LastMessage();
    return message.empty() ? nil : StringFromCString(message.c_str());
}

- (BOOL)mednafenNetplaySupported {
    // netplay.cpp is always compiled into Provenance's Mednafen build.
    return YES;
}

- (BOOL)netplayConnectToHost:(NSString *)host
                        port:(uint16_t)port
                    nickname:(NSString *)nickname
                    password:(NSString *)password
                   spectator:(BOOL)spectator
                       error:(NSError *__autoreleasing _Nullable *)error {
    const char *hostCStr = host.UTF8String;
    if (host.length == 0 || !hostCStr || port == 0) {
        if (error) {
            *error = [NSError errorWithDomain:PVMednafenNetplayErrorDomain
                                         code:PVMednafenNetplayErrorInvalidSettings
                                     userInfo:@{NSLocalizedDescriptionKey: @"A host address and port are required."}];
        }
        return NO;
    }

    const int status = g_status.load();
    if (status == PVMednafenNetplayStatusConnecting || status == PVMednafenNetplayStatusConnected) {
        if (error) {
            *error = [NSError errorWithDomain:PVMednafenNetplayErrorDomain
                                         code:PVMednafenNetplayErrorAlreadyActive
                                     userInfo:@{NSLocalizedDescriptionKey: @"A Mednafen netplay session is already active."}];
        }
        return NO;
    }

    PendingConnect request;
    request.host = hostCStr;
    request.port = port;
    request.nickname = nickname.UTF8String ?: "";
    request.password = password.UTF8String ?: "";
    request.spectator = spectator;

    {
        std::lock_guard<std::mutex> lock(g_mailboxMutex);
        g_pendingConnect = request;
        g_hasPendingConnect = true;
        SetLastMessage(std::string());
        g_status.store(PVMednafenNetplayStatusConnecting);
    }

    DLOG(@"[Mednafen Netplay] Connect requested → %@:%u nick=%@ password=%@ spectator=%d",
         host, port, nickname, password.length > 0 ? @"<set>" : @"<empty>", spectator);
    return YES;
}

- (void)netplayDisconnect {
    DLOG(@"[Mednafen Netplay] Disconnect requested.");
    std::lock_guard<std::mutex> lock(g_mailboxMutex);
    g_hasPendingConnect = false;
    g_pendingDisconnect = true;
    g_needExit.store(true);
    g_status.store(PVMednafenNetplayStatusIdle);
}

/// Emulation thread, before MDFNI_Emulate: carry out queued requests.
- (void)netplayWillEmulateFrame {
    bool doDisconnect = false;
    bool doConnect = false;
    PendingConnect request;
    {
        std::lock_guard<std::mutex> lock(g_mailboxMutex);
        doDisconnect = g_pendingDisconnect;
        doConnect = g_hasPendingConnect;
        if (doConnect) {
            request = g_pendingConnect;
        }
        g_pendingDisconnect = false;
        g_hasPendingConnect = false;
        if (doDisconnect) {
            // The disconnect below doesn't block, so stop aborting waits now.
            g_needExit.store(false);
        }
    }

    if (doDisconnect) {
        g_localDisconnect = true;
        Mednafen::MDFNI_NetplayDisconnect();
        g_localDisconnect = false;
        g_abortReason = AbortReason::none;
    }
    if (doConnect) {
        PerformConnect(request);
    }
    g_lastProgressMS.store(NowMS());
}

/// Emulation thread, after MDFNI_Emulate.
- (void)netplayDidEmulateFrame {
    g_lastProgressMS.store(0);

    // Behind the server (after a pause or a hitch): run the next frames
    // without the loop's frame pacing until caught up. emulation_run resets
    // gameInterval through -setGameSpeed: every frame, so this lasts one frame.
    if (g_behind.load() && g_status.load() == PVMednafenNetplayStatusConnected) {
        self->gameInterval = 0;
        g_catchingUp = true;
    } else if (g_catchingUp) {
        g_catchingUp = false;
        [self setGameSpeed:self.gameSpeed];
    }
}

/// Main thread, before a pause waits for the current frame to finish.
- (void)netplayWillSetPause:(BOOL)paused {
    g_pauseRequested.store(paused);
}

/// Before the emulation thread stops: unblock a frame waiting on the network.
- (void)netplayPrepareForTeardown {
    g_teardown.store(true);
}

/// After the emulation thread has stopped: close everything and reset.
- (void)netplayTeardown {
    [MednafenGameCoreBridge stopNetplayServer];

    g_localDisconnect = true;
    Mednafen::MDFNI_NetplayDisconnect();
    g_localDisconnect = false;

    {
        std::lock_guard<std::mutex> lock(g_mailboxMutex);
        g_pendingDisconnect = false;
        g_hasPendingConnect = false;
        g_needExit.store(false);
        g_status.store(PVMednafenNetplayStatusIdle);
    }
    g_lastProgressMS.store(0);
    g_behind.store(false);
    g_pauseRequested.store(false);
    g_connectCallActive = false;
    g_abortReason = AbortReason::none;
    g_catchingUp = false;
    g_lastServerText.clear();
    SetLastMessage(std::string());
    g_teardown.store(false);
}

// MARK: - Embedded server

+ (BOOL)startNetplayServerOnPort:(uint16_t)port
                        password:(nullable NSString *)password
                      maxClients:(NSInteger)maxClients
                           error:(NSError *__autoreleasing _Nullable *)error {
    std::lock_guard<std::mutex> lock(g_serverMutex);

    MednafenServerResult result = MednafenServerResultAlreadyRunning;
    if (!g_serverThread.joinable()) {
        const std::string passwordString = password.UTF8String ?: "";
        MednafenServerConfig config = {};
        config.maxClients = (int32_t)maxClients;
        config.connectTimeoutSeconds = kServerConnectTimeoutSeconds;
        config.port = port;
        config.idleTimeoutSeconds = kServerIdleTimeoutSeconds;
        config.password = passwordString.c_str();
        result = mednafen_server_open(&config, ServerLog);
    }

    if (result == MednafenServerResultOK) {
        try {
            g_serverThread = std::thread([] {
                pthread_setname_np(kServerThreadName);
                // The server paces games at their frame rate; keep it on time.
                pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
                mednafen_server_run();
            });
            ILOG(@"[Mednafen Netplay] Server listening on port %u", port);
            return YES;
        } catch (std::system_error &e) {
            ELOG(@"[Mednafen Netplay] Could not start the server thread: %s", e.what());
            // Open but never run: let run() see the stop and close everything.
            mednafen_server_request_stop();
            mednafen_server_run();
            result = MednafenServerResultOutOfMemory;
        }
    }

    NSString *description = ServerFailureDescription(result, port);
    ELOG(@"[Mednafen Netplay] Server failed to start: %@", description);
    if (error) {
        *error = [NSError errorWithDomain:PVMednafenNetplayErrorDomain
                                     code:PVMednafenNetplayErrorServerFailed
                                 userInfo:@{NSLocalizedDescriptionKey: description}];
    }
    return NO;
}

+ (void)stopNetplayServer {
    std::lock_guard<std::mutex> lock(g_serverMutex);
    if (!g_serverThread.joinable()) {
        return;
    }
    mednafen_server_request_stop();
    g_serverThread.join();
    ILOG(@"[Mednafen Netplay] Server stopped.");
}

+ (BOOL)netplayServerRunning {
    std::lock_guard<std::mutex> lock(g_serverMutex);
    return g_serverThread.joinable();
}

+ (NSInteger)netplayServerPlayerCount {
    return mednafen_server_client_count();
}

@end
