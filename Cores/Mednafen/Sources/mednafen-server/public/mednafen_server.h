//
//  mednafen_server.h
//  PVMednafen
//
//  Provenance addition: the C API of the vendored mednafen-server 0.5.2
//  (src/mednafen-server.cpp), compiled with PROVENANCE_EMBEDDED_SERVER so a
//  netplay host can run the server inside the app.
//
//  The server keeps its state in globals, so there is one server per process:
//    1. mednafen_server_open() binds and listens (synchronously), or fails.
//    2. mednafen_server_run() runs the server loop on the calling thread until
//       mednafen_server_request_stop(), then closes every socket and frees
//       everything. Call it once after every successful open.
//

#ifndef MEDNAFEN_SERVER_H
#define MEDNAFEN_SERVER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Server settings. The first three are required, as in the server's config file.
typedef struct MednafenServerConfig {
    /// Maximum simultaneous connections (`maxclients`).
    int32_t maxClients;
    /// Seconds a new connection has to log in (`connecttimeout`).
    int32_t connectTimeoutSeconds;
    /// TCP port to listen on, IPv4 and IPv6 (`port`).
    uint16_t port;
    /// Seconds without data before a player is dropped (`idletimeout`); 0 = server default (30).
    int32_t idleTimeoutSeconds;
    /// Server password (`password`); NULL or "" for none.
    const char *password;
} MednafenServerConfig;

typedef enum MednafenServerResult {
    MednafenServerResultOK             = 0,
    MednafenServerResultAlreadyRunning = 1,
    MednafenServerResultInvalidConfig  = 2,
    MednafenServerResultOutOfMemory    = 3,
    MednafenServerResultSocketFailed   = 4,
    MednafenServerResultBindFailed     = 5,
    MednafenServerResultListenFailed   = 6,
} MednafenServerResult;

/// Receives each line the server would have printed to stdout.
/// Called on the thread that runs the server.
typedef void (*MednafenServerLogFunction)(const char *line);

/// Binds and listens on `config->port`. On failure nothing stays open.
MednafenServerResult mednafen_server_open(const MednafenServerConfig *config,
                                          MednafenServerLogFunction log);

/// Runs the server until mednafen_server_request_stop(), then shuts it down.
/// Returns immediately if no server is open.
void mednafen_server_run(void);

/// Asks mednafen_server_run() to return. Safe from any thread; the loop
/// notices within one tick (at most 25 ms).
void mednafen_server_request_stop(void);

/// Players in the most populated game on the running server (0 when stopped).
/// Players with a different game (MD5) are in a separate game, not counted here.
int32_t mednafen_server_client_count(void);

/// Remote players can't log in to a game until the host — a client connected
/// over loopback (127.0.0.1 / ::1) — is in it. They are told why and dropped.
/// Tests only: the next accepted connection counts as remote even over loopback.
void mednafen_server_testing_treat_next_connection_as_remote(void);

#ifdef __cplusplus
}
#endif

#endif /* MEDNAFEN_SERVER_H */
