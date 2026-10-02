/* Provenance-owned replacement for mGBA's CMake-generated version.c
 * (mgba/src/core/version.c.in, values as mgba/version.cmake computes them for
 * a master checkout). Keep these in step with the mgba submodule commit when
 * it is bumped.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
#include <mgba/core/version.h>

MGBA_EXPORT const char* const gitCommit = "c3c8e5e813f245028de118a56734e1dc0f35ce2a";
MGBA_EXPORT const char* const gitCommitShort = "c3c8e5e8";
MGBA_EXPORT const char* const gitBranch = "master";
MGBA_EXPORT const int gitRevision = 9146;
MGBA_EXPORT const char* const binaryName = "mgba";
MGBA_EXPORT const char* const projectName = "mGBA";
MGBA_EXPORT const char* const projectVersion = "0.11-9146-c3c8e5e8";
