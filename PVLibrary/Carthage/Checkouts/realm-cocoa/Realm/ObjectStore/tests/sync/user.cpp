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

#include "sync/sync_manager.hpp"
#include "sync/sync_user.hpp"
#include <realm/util/file.hpp>
#include <realm/util/scope_exit.hpp>

using namespace realm;
using namespace realm::util;
using File = realm::util::File;

static const std::string base_path = tmp_dir() + "/realm_objectstore_sync_user/";

TEST_CASE("sync_user: SyncManager `get_user()` API", "[sync]") {
    auto cleanup = util::make_scope_exit([=]() noexcept { SyncManager::shared().reset_for_testing(); });
    reset_test_directory(base_path);
    SyncManager::shared().configure_file_system(base_path, SyncManager::MetadataMode::NoEncryption);
    const std::string identity = "sync_test_identity";
    const std::string token = "1234567890-fake-token";
    const std::string server_url = "https://realm.example.org";

    SECTION("properly creates a new normal user") {
        auto user = SyncManager::shared().get_user({ identity, server_url }, token);
        REQUIRE(user);
        // The expected state for a newly created user:
        REQUIRE(!user->is_admin());
        REQUIRE(user->identity() == identity);
        REQUIRE(user->server_url() == server_url);
        REQUIRE(user->refresh_token() == token);
        REQUIRE(user->state() == SyncUser::State::Active);
    }

    SECTION("properly creates a new user marked as an admin") {
        auto user = SyncManager::shared().get_user({ identity, server_url }, token);
        REQUIRE(user);
        REQUIRE(!user->is_admin());
        user->set_is_admin(true);
        REQUIRE(user->is_admin());
    }

    SECTION("properly retrieves a previously created user, updating fields as necessary") {
        const std::string second_token = "0987654321-fake-token";
        auto first = SyncManager::shared().get_user({ identity, server_url }, token);
        REQUIRE(first);
        REQUIRE(first->identity() == identity);
        REQUIRE(first->refresh_token() == token);
        // Get the user again, but with a different token.
        auto second = SyncManager::shared().get_user({ identity, server_url }, second_token);
        REQUIRE(second == first);
        REQUIRE(second->identity() == identity);
        REQUIRE(second->refresh_token() == second_token);
    }

    SECTION("properly resurrects a logged-out user") {
        const std::string second_token = "0987654321-fake-token";
        auto first = SyncManager::shared().get_user({ identity, server_url }, token);
        REQUIRE(first->identity() == identity);
        first->log_out();
        REQUIRE(first->state() == SyncUser::State::LoggedOut);
        // Get the user again, with a new token.
        auto second = SyncManager::shared().get_user({ identity, server_url }, second_token);
        REQUIRE(second == first);
        REQUIRE(second->identity() == identity);
        REQUIRE(second->refresh_token() == second_token);
        REQUIRE(second->state() == SyncUser::State::Active);
    }
}

TEST_CASE("sync_user: SyncManager `get_admin_token_user()` APIs", "[sync]") {
    auto cleanup = util::make_scope_exit([=]() noexcept { SyncManager::shared().reset_for_testing(); });
    reset_test_directory(base_path);
    SyncManager::shared().configure_file_system(base_path, SyncManager::MetadataMode::NoEncryption);
    const std::string token = "1234567890-fake-token";
    const std::string server_url = "https://realm.example.org";

    SECTION("properly creates a new wraps-admin-token user") {
        auto user = SyncManager::shared().get_admin_token_user(server_url, token);
        REQUIRE(user);
        // The expected state for a newly created user:
        REQUIRE(user->is_admin());
        REQUIRE(user->identity() == "__auth");
        REQUIRE(user->server_url() == server_url);
        REQUIRE(user->refresh_token() == token);
        REQUIRE(user->state() == SyncUser::State::Active);
    }

    SECTION("properly retrieves an existing wraps-admin-token user ") {
        auto user = SyncManager::shared().get_admin_token_user(server_url, token);
        REQUIRE(user);
        auto user2 = SyncManager::shared().get_admin_token_user(server_url, token);
        REQUIRE(user2);
        REQUIRE(user2->is_admin());
        REQUIRE(user2->identity() == "__auth");
        REQUIRE(user2->refresh_token() == token);
    }

    SECTION("properly retrieves a user based on identity") {
        const std::string& identity = "1234567";

        SECTION("if no server URL is provided") {
            auto user = SyncManager::shared().get_admin_token_user_from_identity(identity, none, token);
            REQUIRE(user);
            REQUIRE(user->identity() == "__auth");
            // Retrieve the same user.
            auto user2 = SyncManager::shared().get_admin_token_user_from_identity(identity, none, token);
            REQUIRE(user2);
            REQUIRE(user2->identity() == "__auth");
            REQUIRE(user2->refresh_token() == token);
            REQUIRE(user2->local_identity() == user->local_identity());
        }

        SECTION("if server URL is provided") {
            auto user = SyncManager::shared().get_admin_token_user_from_identity(identity, server_url, token);
            auto user2 = SyncManager::shared().get_admin_token_user_from_identity(identity, server_url, token);
            REQUIRE(user2);
            REQUIRE(user2->identity() == "__auth");
            REQUIRE(user2->refresh_token() == token);
            REQUIRE(user2->local_identity() == user->local_identity());
            // The user should be indexed based on their server URL.
            auto user3 = SyncManager::shared().get_admin_token_user(server_url, token);
            REQUIRE(user3);
            REQUIRE(user3->identity() == "__auth");
            REQUIRE(user3->refresh_token() == token);
            REQUIRE(user3->local_identity() == user->local_identity());
        }
    }
}

TEST_CASE("sync_user: SyncManager `get_existing_logged_in_user()` API", "[sync]") {
    auto cleanup = util::make_scope_exit([=]() noexcept { SyncManager::shared().reset_for_testing(); });
    reset_test_directory(base_path);
    SyncManager::shared().configure_file_system(base_path, SyncManager::MetadataMode::NoEncryption);
    const std::string identity = "sync_test_identity";
    const std::string token = "1234567890-fake-token";
    const std::string server_url = "https://realm.example.org";

    SECTION("properly returns a null pointer when called for a non-existent user") {
        std::shared_ptr<SyncUser> user = SyncManager::shared().get_existing_logged_in_user({ identity, server_url });
        REQUIRE(!user);
    }

    SECTION("properly returns an existing logged-in user") {
        auto first = SyncManager::shared().get_user({ identity, server_url }, token);
        REQUIRE(first->identity() == identity);
        REQUIRE(first->state() == SyncUser::State::Active);
        // Get that user using the 'existing user' API.
        auto second = SyncManager::shared().get_existing_logged_in_user({ identity, server_url });
        REQUIRE(second == first);
        REQUIRE(second->refresh_token() == token);
    }

    SECTION("properly returns a null pointer for a logged-out user") {
        auto first = SyncManager::shared().get_user({ identity, server_url }, token);
        first->log_out();
        REQUIRE(first->identity() == identity);
        REQUIRE(first->state() == SyncUser::State::LoggedOut);
        // Get that user using the 'existing user' API.
        auto second = SyncManager::shared().get_existing_logged_in_user({ identity, server_url });
        REQUIRE(!second);
    }
}

TEST_CASE("sync_user: logout", "[sync]") {
    reset_test_directory(base_path);
    SyncManager::shared().configure_file_system(base_path, SyncManager::MetadataMode::NoEncryption);
    const std::string identity = "sync_test_identity";
    const std::string token = "1234567890-fake-token";
    const std::string server_url = "https://realm.example.org";

    SECTION("properly changes the state of the user object") {
        auto user = SyncManager::shared().get_user({ identity, server_url }, token);
        REQUIRE(user->state() == SyncUser::State::Active);
        user->log_out();
        REQUIRE(user->state() == SyncUser::State::LoggedOut);
    }
}

TEST_CASE("sync_user: user persistence", "[sync]") {
    auto cleanup = util::make_scope_exit([=]() noexcept { SyncManager::shared().reset_for_testing(); });
    reset_test_directory(base_path);
    SyncManager::shared().configure_file_system(base_path, SyncManager::MetadataMode::NoEncryption);
    auto file_manager = SyncFileManager(base_path);
    // Open the metadata separately, so we can investigate it ourselves.
    SyncMetadataManager manager(file_manager.metadata_path(), false);

    SECTION("properly persists a user's information upon creation") {
        const std::string identity = "test_identity_1";
        const std::string token = "token-1";
        const std::string server_url = "https://realm.example.org/1/";
        auto user = SyncManager::shared().get_user({ identity, server_url }, token);
        user->set_is_admin(true);
        // Now try to pull the user out of the shadow manager directly.
        auto metadata = manager.get_or_make_user_metadata(identity, server_url, false);
        REQUIRE(metadata->is_valid());
        REQUIRE(metadata->auth_server_url() == server_url);
        REQUIRE(metadata->user_token() == token);
        REQUIRE(metadata->is_admin());
    }

    SECTION("does not persist wraps-admin-token users upon creation") {
        const std::string identity = "test_identity_1a";
        const std::string token = "token-1a";
        const std::string server_url = "https://realm.example.org/1a/";
        auto user = SyncManager::shared().get_admin_token_user(identity, token);
        // Now try to pull the user out of the shadow manager directly.
        auto metadata = manager.get_or_make_user_metadata(identity, server_url, false);
        REQUIRE(!metadata);
    }

    SECTION("properly persists a user's information when the user is updated") {
        const std::string identity = "test_identity_2";
        const std::string token = "token-2a";
        const std::string server_url = "https://realm.example.org/2/";
        // Create the user and validate it.
        auto first = SyncManager::shared().get_user({ identity, server_url }, token);
        first->set_is_admin(true);
        auto first_metadata = manager.get_or_make_user_metadata(identity, server_url, false);
        REQUIRE(first_metadata->is_valid());
        REQUIRE(first_metadata->user_token() == token);
        REQUIRE(first_metadata->is_admin());
        const std::string token_2 = "token-2b";
        // Update the user.
        auto second = SyncManager::shared().get_user({ identity, server_url }, token_2);
        auto second_metadata = manager.get_or_make_user_metadata(identity, server_url, false);
        second->set_is_admin(false);
        REQUIRE(second_metadata->is_valid());
        REQUIRE(second_metadata->user_token() == token_2);
        REQUIRE(!second_metadata->is_admin());
    }

    SECTION("properly marks a user when the user is logged out") {
        const std::string identity = "test_identity_3";
        const std::string token = "token-3";
        const std::string server_url = "https://realm.example.org/3/";
        // Create the user and validate it.
        auto user = SyncManager::shared().get_user({ identity, server_url }, token);
        auto marked_users = manager.all_users_marked_for_removal();
        REQUIRE(marked_users.size() == 0);
        // Log out the user.
        user->log_out();
        marked_users = manager.all_users_marked_for_removal();
        REQUIRE(marked_users.size() == 1);
        REQUIRE(results_contains_user(marked_users, identity, server_url));
    }

    SECTION("properly unmarks a logged-out user when it's requested again") {
        const std::string identity = "test_identity_3";
        const std::string token = "token-4a";
        const std::string server_url = "https://realm.example.org/3/";
        // Create the user and log it out.
        auto first = SyncManager::shared().get_user({ identity, server_url }, token);
        first->log_out();
        auto marked_users = manager.all_users_marked_for_removal();
        REQUIRE(marked_users.size() == 1);
        REQUIRE(results_contains_user(marked_users, identity, server_url));
        // Log the user back in.
        const std::string token_2 = "token-4b";
        auto second = SyncManager::shared().get_user({ identity, server_url }, token_2);
        marked_users = manager.all_users_marked_for_removal();
        REQUIRE(marked_users.size() == 0);
    }
}
