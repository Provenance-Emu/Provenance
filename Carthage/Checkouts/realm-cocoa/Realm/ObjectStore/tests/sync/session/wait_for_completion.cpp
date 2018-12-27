////////////////////////////////////////////////////////////////////////////
//
// Copyright 2017 Realm Inc.
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

#include "catch.hpp"

#include "sync/session/session_util.hpp"

#include "util/event_loop.hpp"

#include <realm/util/scope_exit.hpp>

using namespace realm;
using namespace realm::util;

TEST_CASE("SyncSession: wait_for_download_completion() API", "[sync]") {
    if (!EventLoop::has_implementation())
        return;

    const std::string dummy_auth_url = "https://realm.example.org";

    auto cleanup = util::make_scope_exit([=]() noexcept { SyncManager::shared().reset_for_testing(); });
    SyncServer server;
    // Disable file-related functionality and metadata functionality for testing purposes.
    SyncManager::shared().configure_file_system(tmp_dir(), SyncManager::MetadataMode::NoMetadata);

    std::atomic<bool> handler_called(false);

    SECTION("works properly when called after the session is bound") {
        auto user = SyncManager::shared().get_user({ "user-async-wait-download-1", dummy_auth_url }, "not_a_real_token");
        auto session = sync_session(server, user, "/async-wait-download-1",
                                    [](const auto&, const auto&) { return s_test_token; },
                                    [](auto, auto) { });
        EventLoop::main().run_until([&] { return sessions_are_active(*session); });
        // Register the download-completion notification
        CHECK(session->wait_for_download_completion([&](auto) {
            handler_called = true;
        }));
        EventLoop::main().run_until([&] { return handler_called == true; });
    }

    SECTION("works properly when called on a session waiting for its access token") {
        auto user = SyncManager::shared().get_user({ "user-async-wait-download-2", dummy_auth_url }, "not_a_real_token");
        std::atomic<bool> login_handler_called(false);
        auto server_path = "/async-wait-download-2";
        std::shared_ptr<SyncSession> session = sync_session_with_bind_handler(server, user, server_path,
                                                                              [&](auto, auto, std::shared_ptr<SyncSession> s){
                                                                                  session = std::move(s);
                                                                                  login_handler_called = true;
                                                                              },
                                                                              [](auto, auto) { });
        // Register the download-completion notification
        REQUIRE(session->wait_for_download_completion([&](auto) {
            handler_called = true;
        }));
        EventLoop::main().run_until([&] { return login_handler_called == true; });
        REQUIRE(session);
        REQUIRE(handler_called == false);
        spin_runloop();
        REQUIRE(handler_called == false);
        // Now bind the session
        session->refresh_access_token(s_test_token, server.base_url() + server_path);
        EventLoop::main().run_until([&] { return sessions_are_active(*session); });
        EventLoop::main().run_until([&] { return handler_called == true; });
    }

    SECTION("works properly when called on a logged-out session") {
        const auto user_id = "user-async-wait-download-3";
        auto user = SyncManager::shared().get_user({ user_id, dummy_auth_url }, "not_a_real_token");
        auto session = sync_session(server, user, "/user-async-wait-download-3",
                                    [](const auto&, const auto&) { return s_test_token; },
                                    [](auto, auto) { });
        EventLoop::main().run_until([&] { return sessions_are_active(*session); });
        // Log the user out, and wait for the sessions to log out.
        user->log_out();
        EventLoop::main().run_until([&] { return sessions_are_inactive(*session); });
        // Register the download-completion notification
        REQUIRE(session->wait_for_download_completion([&](auto) {
            handler_called = true;
        }));
        spin_runloop();
        REQUIRE(handler_called == false);
        // Log the user back in
        user = SyncManager::shared().get_user({ user_id, dummy_auth_url }, "not_a_real_token_either");
        EventLoop::main().run_until([&] { return sessions_are_active(*session); });
        // Now, wait for the completion handler to be called.
        EventLoop::main().run_until([&] { return handler_called == true; });
    }

    SECTION("aborts properly when queued and the session errors out") {
        using ProtocolError = realm::sync::ProtocolError;
        auto user = SyncManager::shared().get_user({ "user-async-wait-download-4", dummy_auth_url }, "not_a_real_token");
        std::atomic<bool> login_handler_called(false);
        std::atomic<int> error_count(0);
        auto server_path = "/async-wait-download-4";
        std::shared_ptr<SyncSession> session = sync_session_with_bind_handler(server, user, server_path,
                                                                              [&](auto, auto, std::shared_ptr<SyncSession> s){
                                                                                  session = std::move(s);
                                                                                  login_handler_called = true;
                                                                              },
                                                                              [&](auto, auto) { ++error_count; });
        // Register the download-completion notification
        REQUIRE(session->wait_for_download_completion([&](std::error_code error) {
            REQUIRE(error == util::error::operation_aborted);
            handler_called = true;
        }));
        EventLoop::main().run_until([&] { return login_handler_called == true; });
        REQUIRE(handler_called == false);
        // Now trigger an error
        std::error_code code = std::error_code{static_cast<int>(ProtocolError::bad_syntax), realm::sync::protocol_error_category()};
        SyncSession::OnlyForTesting::handle_error(*session, {code, "Not a real error message", true});
        EventLoop::main().run_until([&] { return error_count > 0; });
        REQUIRE(handler_called == true);
    }
}

TEST_CASE("SyncSession: wait_for_upload_completion() API", "[sync]") {
    if (!EventLoop::has_implementation())
        return;

    const std::string dummy_auth_url = "https://realm.example.org";

    auto cleanup = util::make_scope_exit([=]() noexcept { SyncManager::shared().reset_for_testing(); });
    SyncServer server;
    // Disable file-related functionality and metadata functionality for testing purposes.
    SyncManager::shared().configure_file_system(tmp_dir(), SyncManager::MetadataMode::NoMetadata);

    std::atomic<bool> handler_called(false);

    SECTION("works properly when called after the session is bound") {
        auto user = SyncManager::shared().get_user({ "user-async-wait-upload-1", dummy_auth_url }, "not_a_real_token");
        auto session = sync_session(server, user, "/async-wait-upload-1",
                                    [](const auto&, const auto&) { return s_test_token; },
                                    [](auto, auto) { });
        EventLoop::main().run_until([&] { return sessions_are_active(*session); });
        // Register the upload-completion notification
        CHECK(session->wait_for_upload_completion([&](auto) {
            handler_called = true;
        }));
        EventLoop::main().run_until([&] { return handler_called == true; });
    }

    SECTION("works properly when called on a session waiting for its access token") {
        auto user = SyncManager::shared().get_user({ "user-async-wait-upload-2", dummy_auth_url }, "not_a_real_token");
        std::atomic<bool> login_handler_called(false);
        auto server_path = "/async-wait-upload-2";
        std::shared_ptr<SyncSession> session = sync_session_with_bind_handler(server, user, server_path,
                                                                              [&](auto, auto, std::shared_ptr<SyncSession> s){
                                                                                  session = std::move(s);
                                                                                  login_handler_called = true;
                                                                              },
                                                                              [](auto, auto) { });
        // Register the upload-completion notification
        REQUIRE(session->wait_for_upload_completion([&](auto) {
            handler_called = true;
        }));
        EventLoop::main().run_until([&] { return login_handler_called == true; });
        REQUIRE(session);
        REQUIRE(handler_called == false);
        spin_runloop();
        REQUIRE(handler_called == false);
        // Now bind the session
        session->refresh_access_token(s_test_token, server.base_url() + server_path);
        EventLoop::main().run_until([&] { return sessions_are_active(*session); });
        EventLoop::main().run_until([&] { return handler_called == true; });
    }

    SECTION("works properly when called on a logged-out session") {
        const auto user_id = "user-async-wait-upload-3";
        auto user = SyncManager::shared().get_user({ user_id, dummy_auth_url }, "not_a_real_token");
        auto session = sync_session(server, user, "/user-async-wait-upload-3",
                                    [](const auto&, const auto&) { return s_test_token; },
                                    [](auto, auto) { });
        EventLoop::main().run_until([&] { return sessions_are_active(*session); });
        // Log the user out, and wait for the sessions to log out.
        user->log_out();
        EventLoop::main().run_until([&] { return sessions_are_inactive(*session); });
        // Register the upload-completion notification
        REQUIRE(session->wait_for_upload_completion([&](auto) {
            handler_called = true;
        }));
        spin_runloop();
        REQUIRE(handler_called == false);
        // Log the user back in
        user = SyncManager::shared().get_user({ user_id, dummy_auth_url }, "not_a_real_token_either");
        EventLoop::main().run_until([&] { return sessions_are_active(*session); });
        // Now, wait for the completion handler to be called.
        EventLoop::main().run_until([&] { return handler_called == true; });
    }

    SECTION("aborts properly when queued and the session errors out") {
        using ProtocolError = realm::sync::ProtocolError;
        auto user = SyncManager::shared().get_user({ "user-async-wait-upload-4", dummy_auth_url }, "not_a_real_token");
        std::atomic<bool> login_handler_called(false);
        std::atomic<int> error_count(0);
        auto server_path = "/async-wait-upload-4";
        std::shared_ptr<SyncSession> session = sync_session_with_bind_handler(server, user, server_path,
                                                                              [&](auto, auto, std::shared_ptr<SyncSession> s){
                                                                                  session = std::move(s);
                                                                                  login_handler_called = true;
                                                                              },
                                                                              [&](auto, auto) { ++error_count; });
        // Register the upload-completion notification
        REQUIRE(session->wait_for_upload_completion([&](std::error_code error) {
            REQUIRE(error == util::error::operation_aborted);
            handler_called = true;
        }));
        EventLoop::main().run_until([&] { return login_handler_called == true; });
        REQUIRE(handler_called == false);
        // Now trigger an error
        std::error_code code = std::error_code{static_cast<int>(ProtocolError::bad_syntax), realm::sync::protocol_error_category()};
        SyncSession::OnlyForTesting::handle_error(*session, {code, "Not a real error message", true});
        EventLoop::main().run_until([&] { return error_count > 0; });
        REQUIRE(handler_called == true);
    }
}
