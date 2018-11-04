////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

#define CATCH_CONFIG_RUNNER
#include "catch.hpp"

#include <limits.h>

#ifdef _MSC_VER
#include <Shlwapi.h>
#pragma comment(lib, "Shlwapi.lib")
#else
#include <libgen.h>
#endif

int main(int argc, char** argv) {
#ifdef _MSC_VER
    char path[MAX_PATH];
    if (GetModuleFileNameA(NULL, path, sizeof(path)) == 0) {
        fprintf(stderr, "Failed to retrieve path to exectuable.\n");
        return 1;
    }
    PathRemoveFileSpecA(path);
    SetCurrentDirectoryA(path);
#else
    char executable[PATH_MAX];
    realpath(argv[0], executable);
    const char* directory = dirname(executable);
    chdir(directory);
#endif

    int result = Catch::Session().run(argc, argv);
    return result < 0xff ? result : 0xff;
}
