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

#include "shared_realm.hpp"
#include "sync/sync_manager.hpp"
#include <realm/util/file.hpp>
#include <realm/util/scope_exit.hpp>

#include <fstream>

using namespace realm;
using namespace realm::util;
using File = realm::util::File;

static const std::string base_path = tmp_dir() + "/realm_objectstore_sync_file/";

static void prepare_sync_manager_test() {
    // Remove the base directory in /tmp where all test-related file status lives.
    try_remove_dir_recursive(base_path);
    const std::string manager_path = base_path + "syncmanager/";
    util::make_dir(base_path);
    util::make_dir(manager_path);
}

TEST_CASE("sync_file: percent-encoding APIs", "[sync]") {
    SECTION("does not encode a string that has no restricted characters") {
        const std::string expected = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_-";
        auto actual = make_percent_encoded_string(expected);
        REQUIRE(actual == expected);
    }

    SECTION("properly encodes a sample Realm URL") {
        const std::string expected = "realms%3A%2F%2Fexample.com%2F%7E%2Ffoo_bar%2Fuser-realm";
        const std::string raw_string = "realms://example.com/~/foo_bar/user-realm";
        auto actual = make_percent_encoded_string(raw_string);
        REQUIRE(actual == expected);
    }

    SECTION("properly decodes a sample Realm URL") {
        const std::string expected = "realms://example.com/~/foo_bar/user-realm";
        const std::string encoded_string = "realms%3A%2F%2Fexample.com%2F%7E%2Ffoo_bar%2Fuser-realm";
        auto actual = make_raw_string(encoded_string);
        REQUIRE(actual == expected);
    }

    SECTION("properly encodes non-latin characters") {
        const std::string expected = "\%D0\%BF\%D1\%80\%D0\%B8\%D0\%B2\%D0\%B5\%D1\%82";
        const std::string raw_string = "\xd0\xbf\xd1\x80\xd0\xb8\xd0\xb2\xd0\xb5\xd1\x82";
        auto actual = make_percent_encoded_string(raw_string);
        REQUIRE(actual == expected);
    }

    SECTION("properly decodes non-latin characters") {
        const std::string expected = "\xd0\xbf\xd1\x80\xd0\xb8\xd0\xb2\xd0\xb5\xd1\x82";
        const std::string encoded_string = "\%D0\%BF\%D1\%80\%D0\%B8\%D0\%B2\%D0\%B5\%D1\%82";
        auto actual = make_raw_string(encoded_string);
        REQUIRE(actual == expected);
    }
}

TEST_CASE("sync_file: URL manipulation APIs", "[sync]") {
    SECTION("properly concatenates a path when the path has a trailing slash") {
        const std::string expected = "/foo/bar";
        const std::string path = "/foo/";
        const std::string component = "bar";
        auto actual = file_path_by_appending_component(path, component);
        REQUIRE(actual == expected);
    }

    SECTION("properly concatenates a path when the component has a leading slash") {
        const std::string expected = "/foo/bar";
        const std::string path = "/foo";
        const std::string component = "/bar";
        auto actual = file_path_by_appending_component(path, component);
        REQUIRE(actual == expected);
    }

    SECTION("properly concatenates a path when both arguments have slashes") {
        const std::string expected = "/foo/bar";
        const std::string path = "/foo/";
        const std::string component = "/bar";
        auto actual = file_path_by_appending_component(path, component);
        REQUIRE(actual == expected);
    }

    SECTION("properly concatenates a directory path when the component doesn't have a trailing slash") {
        const std::string expected = "/foo/bar/";
        const std::string path = "/foo/";
        const std::string component = "/bar";
        auto actual = file_path_by_appending_component(path, component, FilePathType::Directory);
        REQUIRE(actual == expected);
    }

    SECTION("properly concatenates a directory path when the component has a trailing slash") {
        const std::string expected = "/foo/bar/";
        const std::string path = "/foo/";
        const std::string component = "/bar/";
        auto actual = file_path_by_appending_component(path, component, FilePathType::Directory);
        REQUIRE(actual == expected);
    }

    SECTION("properly concatenates an extension when the path has a trailing dot") {
        const std::string expected = "/foo.management";
        const std::string path = "/foo.";
        const std::string component = "management";
        auto actual = file_path_by_appending_extension(path, component);
        REQUIRE(actual == expected);
    }

    SECTION("properly concatenates a path when the extension has a leading dot") {
        const std::string expected = "/foo.management";
        const std::string path = "/foo";
        const std::string component = ".management";
        auto actual = file_path_by_appending_extension(path, component);
        REQUIRE(actual == expected);
    }

    SECTION("properly concatenates a path when both arguments have dots") {
        const std::string expected = "/foo.management";
        const std::string path = "/foo.";
        const std::string component = ".management";
        auto actual = file_path_by_appending_extension(path, component);
        REQUIRE(actual == expected);
    }
}

TEST_CASE("sync_file: SyncFileManager APIs", "[sync]") {
    const std::string local_identity = "123456789";
    const std::string manager_path = base_path + "syncmanager/";
    prepare_sync_manager_test();
    auto manager = SyncFileManager(manager_path);

    SECTION("user directory APIs") {
        const std::string expected = manager_path + "realm-object-server/" + local_identity + "/";

        SECTION("getting a user directory") {
            SECTION("that didn't exist before succeeds") {
                auto actual = manager.user_directory(local_identity);
                REQUIRE(actual == expected);
                REQUIRE_DIR_EXISTS(expected);
            }
            SECTION("that already existed succeeds") {
                auto actual = manager.user_directory(local_identity);
                REQUIRE(actual == expected);
                REQUIRE_DIR_EXISTS(expected);
            }
        }

        SECTION("deleting a user directory") {
            manager.user_directory(local_identity);
            REQUIRE_DIR_EXISTS(expected);
            SECTION("that wasn't yet deleted succeeds") {
                manager.remove_user_directory(local_identity);
                REQUIRE_DIR_DOES_NOT_EXIST(expected);
            }
            SECTION("that was already deleted succeeds") {
                manager.remove_user_directory(local_identity);
                REQUIRE(opendir(expected.c_str()) == NULL);
                REQUIRE_DIR_DOES_NOT_EXIST(expected);
            }
        }

        SECTION("admin user directory migration") {
            const std::string& server_url = "https://realm.example.org:9090/realm";
            const std::string& token = "fake-token";
            prepare_sync_manager_test();
            auto cleanup = util::make_scope_exit([=]() noexcept { SyncManager::shared().reset_for_testing(); });
            SyncManager::shared().configure_file_system(base_path + "syncmanager/", SyncManager::MetadataMode::NoEncryption);

            SECTION("migrating a user directory if an old identity is specified") {
                // Create the "old directory"
                manager.user_directory(local_identity);
                REQUIRE_DIR_EXISTS(expected);
                // Perform the migration.
                auto user = SyncManager::shared().get_admin_token_user(server_url, token, local_identity);
                REQUIRE(user);
                const auto& newdir = manager_path + "realm-object-server/__auth" + util::make_percent_encoded_string(server_url) + "/";
                // The directory should have been renamed properly.
                REQUIRE_DIR_DOES_NOT_EXIST(expected);
                REQUIRE_DIR_EXISTS(newdir);
            }

            SECTION("doing nothing if an old identity is specified but no dir exists") {
                REQUIRE_DIR_DOES_NOT_EXIST(expected);
                auto user = SyncManager::shared().get_admin_token_user(server_url, token, local_identity);
                REQUIRE(user);
                // Shouldn't throw
            }
        }
    }

    SECTION("Realm path APIs") {
        auto relative_path = "realms://r.example.com/~/my/realm/path";

        SECTION("getting a Realm path") {
            const std::string expected = manager_path + "realm-object-server/123456789/realms%3A%2F%2Fr.example.com%2F%7E%2Fmy%2Frealm%2Fpath";
            auto actual = manager.path(local_identity, relative_path);
            REQUIRE(expected == actual);
        }

        SECTION("deleting a Realm for a valid user") {
            manager.path(local_identity, relative_path);
            // Create the required files
            auto realm_base_path = manager_path + "realm-object-server/123456789/realms%3A%2F%2Fr.example.com%2F%7E%2Fmy%2Frealm%2Fpath";
            REQUIRE(create_dummy_realm(realm_base_path));
            REQUIRE(File::exists(realm_base_path));
            REQUIRE(File::exists(realm_base_path + ".lock"));
            REQUIRE_DIR_EXISTS(realm_base_path + ".management");
            // Delete the Realm
            manager.remove_realm(local_identity, relative_path);
            // Ensure the files don't exist anymore
            REQUIRE(!File::exists(realm_base_path));
            REQUIRE(!File::exists(realm_base_path + ".lock"));
            REQUIRE_DIR_DOES_NOT_EXIST(realm_base_path + ".management");
        }

        SECTION("deleting a Realm for an invalid user") {
            manager.remove_realm("invalid_user", relative_path);
        }
    }

    SECTION("Utility path APIs") {
        auto metadata_dir = manager_path + "realm-object-server/io.realm.object-server-utility/metadata/";

        SECTION("getting the metadata path") {
            auto path = manager.metadata_path();
            REQUIRE(path == (metadata_dir + "sync_metadata.realm"));
        }

        SECTION("removing the metadata Realm") {
            manager.metadata_path();
            REQUIRE_DIR_EXISTS(metadata_dir);
            manager.remove_metadata_realm();
            REQUIRE_DIR_DOES_NOT_EXIST(metadata_dir);
        }
    }
}
