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

#ifndef REALM_SYNC_TEST_UTILS_HPP
#define REALM_SYNC_TEST_UTILS_HPP

#include "catch.hpp"

#include "sync/impl/sync_file.hpp"
#include "sync/impl/sync_metadata.hpp"

namespace realm {

/// Open a Realm at a given path, creating its files.
bool create_dummy_realm(std::string path);
void reset_test_directory(const std::string& base_path);
bool results_contains_user(SyncUserMetadataResults& results, const std::string& identity, const std::string& auth_server);
bool results_contains_original_name(SyncFileActionMetadataResults& results, const std::string& original_name);
std::string tmp_dir();
std::vector<char> make_test_encryption_key(const char start = 0);

} // namespace realm

#define REQUIRE_DIR_EXISTS(macro_path) do { \
    DIR *dir_listing = opendir((macro_path).c_str()); \
    CHECK(dir_listing); \
    if (dir_listing) closedir(dir_listing); \
} while (0)

#define REQUIRE_DIR_DOES_NOT_EXIST(macro_path) do { \
    DIR *dir_listing = opendir((macro_path).c_str()); \
    CHECK(dir_listing == NULL); \
    if (dir_listing) closedir(dir_listing); \
} while (0)

#define REQUIRE_REALM_EXISTS(macro_path) do { \
	REQUIRE(realm::util::File::exists(macro_path)); \
	REQUIRE(realm::util::File::exists((macro_path) + ".lock")); \
	REQUIRE_DIR_EXISTS((macro_path) + ".management"); \
} while (0)

#define REQUIRE_REALM_DOES_NOT_EXIST(macro_path) do { \
	REQUIRE(!realm::util::File::exists(macro_path)); \
	REQUIRE(!realm::util::File::exists((macro_path) + ".lock")); \
	REQUIRE_DIR_DOES_NOT_EXIST((macro_path) + ".management"); \
} while (0)

#endif // REALM_SYNC_TEST_UTILS_HPP
