#ifndef MednafenServerBridge_h
#define MednafenServerBridge_h

#include <stdint.h>

/// Main entry point for the Mednafen server
/// @param configPath Path to the configuration file
/// @return Exit code from the server
int32_t mednafen_server_main(const char* configPath);

#endif /* MednafenServerBridge_h */
