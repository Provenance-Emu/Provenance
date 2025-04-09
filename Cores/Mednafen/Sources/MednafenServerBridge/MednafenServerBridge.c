#include "MednafenServerBridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Forward declaration of the main function from the Mednafen server
extern int main_function(int argc, char *argv[]);

int32_t mednafen_server_main(const char* configPath) {
    // Create the arguments array for the Mednafen server
    char* argv[2];

    // Program name (first argument)
    argv[0] = strdup("mednafen-server");

    // Config file path (second argument)
    argv[1] = strdup(configPath);

    // Call the main function of the Mednafen server
    int result = main_function(2, argv);

    // Free allocated memory
    free(argv[0]);
    free(argv[1]);

    return (int32_t)result;
}
