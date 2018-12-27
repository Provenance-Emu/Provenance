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

#include "sync_test_utils.hpp"

namespace realm {

bool create_dummy_realm(std::string path) {
    Realm::Config config;
    config.path = path;
    try {
        Realm::make_shared_realm(config);
        REQUIRE_REALM_EXISTS(path);
        return true;
    } catch (std::exception&) {
        return false;
    }
}

void reset_test_directory(const std::string& base_path) {
    try_remove_dir_recursive(base_path);
    util::make_dir(base_path);
}

bool results_contains_user(SyncUserMetadataResults& results, const std::string& identity, const std::string& auth_server) {
    for (size_t i = 0; i < results.size(); i++) {
        auto this_result = results.get(i);
        if (this_result.identity() == identity && this_result.auth_server_url() == auth_server) {
            return true;
        }
    }
    return false;
}

bool results_contains_original_name(SyncFileActionMetadataResults& results, const std::string& original_name) {
    for (size_t i = 0; i < results.size(); i++) {
        if (results.get(i).original_name() == original_name) {
            return true;
        }
    }
    return false;
}

std::string tmp_dir() {
    const char* dir = getenv("TMPDIR");
    if (dir && *dir)
        return dir;
#if REALM_ANDROID
    return "/data/local/tmp/";
#else
    return "/tmp/";
#endif
}

std::vector<char> make_test_encryption_key(const char start) {
    std::vector<char> vector;
    vector.reserve(64);
    for (int i=0; i<64; i++) {
        vector.emplace_back((start + i) % 128);
    }
    return vector;
}

}
