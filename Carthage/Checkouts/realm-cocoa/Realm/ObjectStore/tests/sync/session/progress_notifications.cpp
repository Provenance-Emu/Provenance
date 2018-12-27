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

#include "sync/sync_session.hpp"

#include <realm/util/scope_exit.hpp>

using namespace realm;

TEST_CASE("progress notification", "[sync]") {
    using NotifierType = SyncSession::NotifierType;
    _impl::SyncProgressNotifier progress;

    SECTION("callback is not called prior to first update") {
        bool callback_was_called = false;
        progress.register_callback([&](auto, auto) { callback_was_called = true; }, NotifierType::upload, false);
        progress.register_callback([&](auto, auto) { callback_was_called = true; }, NotifierType::download, false);
        REQUIRE_FALSE(callback_was_called);
    }

    SECTION("callback is invoked immediately when a progress update has already occurred") {
        progress.set_local_version(1);
        progress.update(0, 0, 0, 0, 1, 1);

        bool callback_was_called = false;
        SECTION("for upload notifications, with no data transfer ongoing") {
            progress.register_callback([&](auto, auto) { callback_was_called = true; }, NotifierType::upload, false);
            REQUIRE(callback_was_called);
        }

        SECTION("for download notifications, with no data transfer ongoing") {
            progress.register_callback([&](auto, auto) { callback_was_called = true; }, NotifierType::download, false);
        }

        SECTION("can register another notifier while in the initial notification without deadlock") {
            int counter = 0;
            progress.register_callback([&](auto, auto) {
                counter++;
                progress.register_callback([&](auto, auto) {
                    counter++;
                }, NotifierType::upload, false);
            }, NotifierType::download, false);
            REQUIRE(counter == 2);
        }
    }

    SECTION("callback is invoked after each update for streaming notifiers") {
        progress.update(0, 0, 0, 0, 1, 1);

        bool callback_was_called = false;
        uint64_t transferred = 0;
        uint64_t transferrable = 0;
        uint64_t current_transferred = 0;
        uint64_t current_transferrable = 0;

        SECTION("for upload notifications") {
            progress.register_callback([&](auto xferred, auto xferable) {
                transferred = xferred;
                transferrable = xferable;
                callback_was_called = true;
            }, NotifierType::upload, true);
            REQUIRE(callback_was_called);

            // Now manually call the notifier handler a few times.
            callback_was_called = false;
            current_transferred = 60;
            current_transferrable = 912;
            progress.update(25, 26, current_transferred, current_transferrable, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_transferred);
            CHECK(transferrable == current_transferrable);

            // Second callback
            callback_was_called = false;
            current_transferred = 79;
            current_transferrable = 1021;
            progress.update(68, 191, current_transferred, current_transferrable, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_transferred);
            CHECK(transferrable == current_transferrable);

            // Third callback
            callback_was_called = false;
            current_transferred = 150;
            current_transferrable = 1228;
            progress.update(199, 591, current_transferred, current_transferrable, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_transferred);
            CHECK(transferrable == current_transferrable);
        }

        SECTION("for download notifications") {
            progress.register_callback([&](auto xferred, auto xferable) {
                transferred = xferred;
                transferrable = xferable;
                callback_was_called = true;
            }, NotifierType::download, true);
            REQUIRE(callback_was_called);

            // Now manually call the notifier handler a few times.
            callback_was_called = false;
            current_transferred = 60;
            current_transferrable = 912;
            progress.update(current_transferred, current_transferrable, 25, 26, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_transferred);
            CHECK(transferrable == current_transferrable);

            // Second callback
            callback_was_called = false;
            current_transferred = 79;
            current_transferrable = 1021;
            progress.update(current_transferred, current_transferrable, 68, 191, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_transferred);
            CHECK(transferrable == current_transferrable);

            // Third callback
            callback_was_called = false;
            current_transferred = 150;
            current_transferrable = 1228;
            progress.update(current_transferred, current_transferrable, 199, 591, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_transferred);
            CHECK(transferrable == current_transferrable);
        }

        SECTION("token unregistration works") {
            uint64_t token = progress.register_callback([&](auto xferred, auto xferable) {
                transferred = xferred;
                transferrable = xferable;
                callback_was_called = true;
            }, NotifierType::download, true);
            REQUIRE(callback_was_called);

            // Now manually call the notifier handler a few times.
            callback_was_called = false;
            current_transferred = 60;
            current_transferrable = 912;
            progress.update(current_transferred, current_transferrable, 25, 26, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_transferred);
            CHECK(transferrable == current_transferrable);

            // Unregister
            progress.unregister_callback(token);

            // Second callback: should not actually do anything.
            callback_was_called = false;
            current_transferred = 150;
            current_transferrable = 1228;
            progress.update(current_transferred, current_transferrable, 199, 591, 1, 1);
            CHECK(!callback_was_called);
        }

        SECTION("for multiple notifiers") {
            progress.register_callback([&](auto xferred, auto xferable) {
                transferred = xferred;
                transferrable = xferable;
                callback_was_called = true;
            }, NotifierType::download, true);
            REQUIRE(callback_was_called);

            // Register a second notifier.
            bool callback_was_called_2 = false;
            uint64_t transferred_2 = 0;
            uint64_t transferrable_2 = 0;
            progress.register_callback([&](auto xferred, auto xferable) {
                transferred_2 = xferred;
                transferrable_2 = xferable;
                callback_was_called_2 = true;
            }, NotifierType::upload, true);
            REQUIRE(callback_was_called_2);

            // Now manually call the notifier handler a few times.
            callback_was_called = false;
            callback_was_called_2 = false;
            uint64_t current_uploaded = 16;
            uint64_t current_uploadable = 201;
            uint64_t current_downloaded = 68;
            uint64_t current_downloadable = 182;
            progress.update(current_downloaded, current_downloadable, current_uploaded, current_uploadable, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_downloaded);
            CHECK(transferrable == current_downloadable);
            CHECK(callback_was_called_2);
            CHECK(transferred_2 == current_uploaded);
            CHECK(transferrable_2 == current_uploadable);

            // Second callback
            callback_was_called = false;
            callback_was_called_2 = false;
            current_uploaded = 31;
            current_uploadable = 329;
            current_downloaded = 76;
            current_downloadable = 191;
            progress.update(current_downloaded, current_downloadable, current_uploaded, current_uploadable, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_downloaded);
            CHECK(transferrable == current_downloadable);
            CHECK(callback_was_called_2);
            CHECK(transferred_2 == current_uploaded);
            CHECK(transferrable_2 == current_uploadable);
        }
    }

    SECTION("properly runs for non-streaming notifiers") {
        bool callback_was_called = false;
        uint64_t transferred = 0;
        uint64_t transferrable = 0;
        uint64_t current_transferred = 0;
        uint64_t current_transferrable = 0;

        SECTION("for upload notifications") {
            // Prime the progress updater
            current_transferred = 60;
            current_transferrable = 501;
            const uint64_t original_transferrable = current_transferrable;
            progress.update(21, 26, current_transferred, current_transferrable, 1, 1);

            progress.register_callback([&](auto xferred, auto xferable) {
                transferred = xferred;
                transferrable = xferable;
                callback_was_called = true;
            }, NotifierType::upload, false);
            // Wait for the initial callback.
            REQUIRE(callback_was_called);

            // Now manually call the notifier handler a few times.
            callback_was_called = false;
            current_transferred = 66;
            current_transferrable = 582;
            progress.update(25, 26, current_transferred, current_transferrable, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_transferred);
            CHECK(transferrable == original_transferrable);

            // Second callback
            callback_was_called = false;
            current_transferred = original_transferrable + 100;
            current_transferrable = 1021;
            progress.update(68, 191, current_transferred, current_transferrable, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_transferred);
            CHECK(transferrable == original_transferrable);

            // The notifier should be unregistered at this point, and not fire.
            callback_was_called = false;
            current_transferred = original_transferrable + 250;
            current_transferrable = 1228;
            progress.update(199, 591, current_transferred, current_transferrable, 1, 1);
            CHECK(!callback_was_called);
        }

        SECTION("upload notifications are not sent until all local changesets have been processed") {
            progress.set_local_version(4);

            progress.register_callback([&](auto xferred, auto xferable) {
                transferred = xferred;
                transferrable = xferable;
                callback_was_called = true;
            }, NotifierType::upload, false);
            REQUIRE_FALSE(callback_was_called);

            current_transferred = 66;
            current_transferrable = 582;
            progress.update(0, 0, current_transferred, current_transferrable, 1, 3);
            REQUIRE_FALSE(callback_was_called);

            current_transferred = 77;
            current_transferrable = 1021;
            progress.update(0, 0, current_transferred, current_transferrable, 1, 4);
            REQUIRE(callback_was_called);
            CHECK(transferred == current_transferred);
            // should not have captured transferrable from the first update
            CHECK(transferrable == current_transferrable);
        }

        SECTION("for download notifications") {
            // Prime the progress updater
            current_transferred = 60;
            current_transferrable = 501;
            const uint64_t original_transferrable = current_transferrable;
            progress.update(current_transferred, current_transferrable, 21, 26, 1, 1);

            progress.register_callback([&](auto xferred, auto xferable) {
                transferred = xferred;
                transferrable = xferable;
                callback_was_called = true;
            }, NotifierType::download, false);
            // Wait for the initial callback.
            REQUIRE(callback_was_called);

            // Now manually call the notifier handler a few times.
            callback_was_called = false;
            current_transferred = 66;
            current_transferrable = 582;
            progress.update(current_transferred, current_transferrable, 25, 26, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_transferred);
            CHECK(transferrable == original_transferrable);

            // Second callback
            callback_was_called = false;
            current_transferred = original_transferrable + 100;
            current_transferrable = 1021;
            progress.update(current_transferred, current_transferrable, 68, 191, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_transferred);
            CHECK(transferrable == original_transferrable);

            // The notifier should be unregistered at this point, and not fire.
            callback_was_called = false;
            current_transferred = original_transferrable + 250;
            current_transferrable = 1228;
            progress.update(current_transferred, current_transferrable, 199, 591, 1, 1);
            CHECK(!callback_was_called);
        }

        SECTION("download notifications are not sent until a DOWNLOAD message has been received") {
            _impl::SyncProgressNotifier progress;

            progress.register_callback([&](auto xferred, auto xferable) {
                transferred = xferred;
                transferrable = xferable;
                callback_was_called = true;
            }, NotifierType::download, false);

            current_transferred = 100;
            current_transferrable = 100;
            // Last time we ran we downloaded everything, so sync will send us an
            // update reporting that
            progress.update(current_transferred, current_transferrable, 0, 0, 0, 1);
            REQUIRE_FALSE(callback_was_called);

            current_transferred = 100;
            current_transferrable = 200;
            // Next we get a DOWNLOAD message telling us there's more to download
            progress.update(current_transferred, current_transferrable, 0, 0, 1, 1);
            REQUIRE(callback_was_called);
            REQUIRE(current_transferrable == transferrable);
            REQUIRE(current_transferred == transferred);

            current_transferred = 200;
            progress.update(current_transferred, current_transferrable, 0, 0, 1, 1);

            // After the download has completed, new notifications complete immediately
            transferred = 0;
            transferrable = 0;
            callback_was_called = false;

            progress.register_callback([&](auto xferred, auto xferable) {
                transferred = xferred;
                transferrable = xferable;
                callback_was_called = true;
            }, NotifierType::download, false);

            REQUIRE(callback_was_called);
            REQUIRE(current_transferrable == transferrable);
            REQUIRE(current_transferred == transferred);
        }

        SECTION("token unregistration works") {
            // Prime the progress updater
            current_transferred = 60;
            current_transferrable = 501;
            const uint64_t original_transferrable = current_transferrable;
            progress.update(21, 26, current_transferred, current_transferrable, 1, 1);

            uint64_t token = progress.register_callback([&](auto xferred, auto xferable) {
                transferred = xferred;
                transferrable = xferable;
                callback_was_called = true;
            }, NotifierType::upload, false);
            // Wait for the initial callback.
            REQUIRE(callback_was_called);

            // Now manually call the notifier handler a few times.
            callback_was_called = false;
            current_transferred = 66;
            current_transferrable = 912;
            progress.update(25, 26, current_transferred, current_transferrable, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_transferred);
            CHECK(transferrable == original_transferrable);

            // Unregister
            progress.unregister_callback(token);

            // Second callback: should not actually do anything.
            callback_was_called = false;
            current_transferred = 67;
            current_transferrable = 1228;
            progress.update(199, 591, current_transferred, current_transferrable, 1, 1);
            CHECK(!callback_was_called);
        }

        SECTION("for multiple notifiers, different directions") {
            // Prime the progress updater
            uint64_t current_uploaded = 16;
            uint64_t current_uploadable = 201;
            uint64_t current_downloaded = 68;
            uint64_t current_downloadable = 182;
            const uint64_t original_uploadable = current_uploadable;
            const uint64_t original_downloadable = current_downloadable;
            progress.update(current_downloaded, current_downloadable, current_uploaded, current_uploadable, 1, 1);

            progress.register_callback([&](auto xferred, auto xferable) {
                transferred = xferred;
                transferrable = xferable;
                callback_was_called = true;
            }, NotifierType::upload, false);
            REQUIRE(callback_was_called);

            // Register a second notifier.
            bool callback_was_called_2 = false;
            uint64_t downloaded = 0;
            uint64_t downloadable = 0;
            progress.register_callback([&](auto xferred, auto xferable) {
                downloaded = xferred;
                downloadable = xferable;
                callback_was_called_2 = true;
            }, NotifierType::download, false);
            REQUIRE(callback_was_called_2);

            // Now manually call the notifier handler a few times.
            callback_was_called = false;
            callback_was_called_2 = false;
            current_uploaded = 36;
            current_uploadable = 310;
            current_downloaded = 171;
            current_downloadable = 185;
            progress.update(current_downloaded, current_downloadable, current_uploaded, current_uploadable, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_uploaded);
            CHECK(transferrable == original_uploadable);
            CHECK(callback_was_called_2);
            CHECK(downloaded == current_downloaded);
            CHECK(downloadable == original_downloadable);

            // Second callback, last one for the upload notifier
            callback_was_called = false;
            callback_was_called_2 = false;
            current_uploaded = 218;
            current_uploadable = 310;
            current_downloaded = 174;
            current_downloadable = 190;
            progress.update(current_downloaded, current_downloadable, current_uploaded, current_uploadable, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_uploaded);
            CHECK(transferrable == original_uploadable);
            CHECK(callback_was_called_2);
            CHECK(downloaded == current_downloaded);
            CHECK(downloadable == original_downloadable);

            // Third callback, last one for the download notifier
            callback_was_called = false;
            callback_was_called_2 = false;
            current_uploaded = 218;
            current_uploadable = 310;
            current_downloaded = 182;
            current_downloadable = 196;
            progress.update(current_downloaded, current_downloadable, current_uploaded, current_uploadable, 1, 1);
            CHECK(!callback_was_called);
            CHECK(callback_was_called_2);
            CHECK(downloaded == current_downloaded);
            CHECK(downloadable == original_downloadable);

            // Fourth callback, last one for the download notifier
            callback_was_called_2 = false;
            current_uploaded = 220;
            current_uploadable = 410;
            current_downloaded = 192;
            current_downloadable = 591;
            progress.update(current_downloaded, current_downloadable, current_uploaded, current_uploadable, 1, 1);
            CHECK(!callback_was_called);
            CHECK(!callback_was_called_2);
        }

        SECTION("for multiple notifiers, same direction") {
            // Prime the progress updater
            uint64_t current_uploaded = 16;
            uint64_t current_uploadable = 201;
            uint64_t current_downloaded = 68;
            uint64_t current_downloadable = 182;
            const uint64_t original_downloadable = current_downloadable;
            progress.update(current_downloaded, current_downloadable, current_uploaded, current_uploadable, 1, 1);

            progress.register_callback([&](auto xferred, auto xferable) {
                transferred = xferred;
                transferrable = xferable;
                callback_was_called = true;
            }, NotifierType::download, false);
            REQUIRE(callback_was_called);

            // Now manually call the notifier handler a few times.
            callback_was_called = false;
            current_uploaded = 36;
            current_uploadable = 310;
            current_downloaded = 171;
            current_downloadable = 185;
            progress.update(current_downloaded, current_downloadable, current_uploaded, current_uploadable, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_downloaded);
            CHECK(transferrable == original_downloadable);

            // Register a second notifier.
            bool callback_was_called_2 = false;
            uint64_t downloaded = 0;
            uint64_t downloadable = 0;
            const uint64_t original_downloadable_2 = current_downloadable;
            progress.register_callback([&](auto xferred, auto xferable) {
                downloaded = xferred;
                downloadable = xferable;
                callback_was_called_2 = true;
            }, NotifierType::download, false);
            // Wait for the initial callback.
            REQUIRE(callback_was_called_2);

            // Second callback, last one for first notifier
            callback_was_called = false;
            callback_was_called_2 = false;
            current_uploaded = 36;
            current_uploadable = 310;
            current_downloaded = 182;
            current_downloadable = 190;
            progress.update(current_downloaded, current_downloadable, current_uploaded, current_uploadable, 1, 1);
            CHECK(callback_was_called);
            CHECK(transferred == current_downloaded);
            CHECK(transferrable == original_downloadable);
            CHECK(callback_was_called_2);
            CHECK(downloaded == current_downloaded);
            CHECK(downloadable == original_downloadable_2);

            // Third callback, last one for second notifier
            callback_was_called = false;
            callback_was_called_2 = false;
            current_uploaded = 36;
            current_uploadable = 310;
            current_downloaded = 189;
            current_downloadable = 250;
            progress.update(current_downloaded, current_downloadable, current_uploaded, current_uploadable, 1, 1);
            CHECK(!callback_was_called);
            CHECK(callback_was_called_2);
            CHECK(downloaded == current_downloaded);
            CHECK(downloadable == original_downloadable_2);

            // Fourth callback
            callback_was_called_2 = false;
            current_uploaded = 36;
            current_uploadable = 310;
            current_downloaded = 201;
            current_downloadable = 289;
            progress.update(current_downloaded, current_downloadable, current_uploaded, current_uploadable, 1, 1);
            CHECK(!callback_was_called_2);
        }
    }
}
