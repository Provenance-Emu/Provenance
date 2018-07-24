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

#include "util/test_file.hpp"

#include "impl/realm_coordinator.hpp"

#if REALM_ENABLE_SYNC
#include "sync/sync_config.hpp"
#include "sync/sync_manager.hpp"
#include "sync/sync_session.hpp"
#include "schema.hpp"
#endif

#include <realm/disable_sync_to_disk.hpp>
#include <realm/history.hpp>
#include <realm/string_data.hpp>
#include <realm/util/base64.hpp>

#include <cstdlib>

#ifdef _WIN32
#include <io.h>
#include <fcntl.h>

inline static int mkstemp(char* _template) { return _open(_mktemp(_template), _O_CREAT | _O_TEMPORARY, _S_IREAD | _S_IWRITE); }
#else
#include <unistd.h>
#endif

#if REALM_HAVE_CLANG_FEATURE(thread_sanitizer)
#include <condition_variable>
#include <functional>
#include <thread>
#include <map>
#endif

using namespace realm;

TestFile::TestFile()
{
    static std::string tmpdir = [] {
        disable_sync_to_disk();

        const char* dir = getenv("TMPDIR");
        if (dir && *dir)
            return dir;
#if REALM_ANDROID
        return "/data/local/tmp";
#else
        return "/tmp";
#endif
    }();
    path = tmpdir + "/realm.XXXXXX";
    int fd = mkstemp(&path[0]);
    if (fd < 0) {
        int err = errno;
        throw std::system_error(err, std::system_category());
    }
    close(fd);
    unlink(path.c_str());

    schema_version = 0;
}

TestFile::~TestFile()
{
    unlink(path.c_str());
}

InMemoryTestFile::InMemoryTestFile()
{
    in_memory = true;
}

#if REALM_ENABLE_SYNC
SyncTestFile::SyncTestFile(SyncServer& server, std::string name,
                           realm::util::Optional<realm::Schema> realm_schema,
                           bool is_partial)
{
    if (name.empty())
        name = path.substr(path.rfind('/') + 1);
    auto url = server.url_for_realm(name);

    if (realm_schema)
        schema = std::move(realm_schema);

    sync_config = std::make_shared<SyncConfig>(SyncManager::shared().get_user({ "test", url }, "not_a_real_token"), url);
    sync_config->user->set_is_admin(true);
    sync_config->stop_policy = SyncSessionStopPolicy::Immediately;
    sync_config->bind_session_handler = [=](auto&, auto& config, auto session) {
        std::string token, encoded;
        // FIXME: Tokens without a path are currently implicitly considered
        // admin tokens by the sync service, so until that changes we need to
        // add a path for non-admin users
        if (config.user->is_admin())
            token = "{\"identity\": \"test\", \"access\": [\"download\", \"upload\"]}";
        else {
            auto path = "/" + name;
            if (config.is_partial)
                path += "/__partial/" + config.user->identity() + "/" + SyncConfig::partial_sync_identifier(*config.user);
            token = util::format("{\"identity\": \"test\", \"path\": \"%1\", \"access\": [\"download\", \"upload\"]}", path);
        }
        encoded.resize(base64_encoded_size(token.size()));
        base64_encode(token.c_str(), token.size(), &encoded[0], encoded.size());
        session->refresh_access_token(encoded, config.realm_url());
    };
    sync_config->error_handler = [](auto, auto) { abort(); };
    sync_config->is_partial = is_partial;
    schema_mode = SchemaMode::Additive;
}

sync::Server::Config TestLogger::server_config() {
    sync::Server::Config config;
#if TEST_ENABLE_SYNC_LOGGING
    auto logger = new util::StderrLogger;
    logger->set_level_threshold(util::Logger::Level::all);
    config.logger = logger;
#else
    config.logger = new TestLogger;
#endif
    return config;
}

SyncServer::SyncServer(StartImmediately start_immediately)
: m_server(util::make_temp_dir(), util::none, TestLogger::server_config())
{
#if TEST_ENABLE_SYNC_LOGGING
    SyncManager::shared().set_log_level(util::Logger::Level::all);
#else
    SyncManager::shared().set_log_level(util::Logger::Level::off);
#endif

    uint64_t port;
    while (true) {
        // Try to pick a random available port, or loop forever if other
        // problems occur because there's no specific error for "port in use"
        try {
            port = fastrand(65536 - 1000) + 1000;
            m_server.start("127.0.0.1", util::to_string(port));
            break;
        }
        catch (std::runtime_error const&) {
            continue;
        }
    }
    m_url = util::format("realm://127.0.0.1:%1", port);
    if (start_immediately)
        start();
}

SyncServer::~SyncServer()
{
    stop();
    SyncManager::shared().reset_for_testing();
}

void SyncServer::start()
{
    REALM_ASSERT(!m_thread.joinable());
    m_thread = std::thread([this]{ m_server.run(); });
}

void SyncServer::stop()
{
    m_server.stop();
    if (m_thread.joinable())
        m_thread.join();
}

std::string SyncServer::url_for_realm(StringData realm_name) const
{
    return util::format("%1/%2", m_url, realm_name);
}

static void wait_for_session(Realm& realm, bool (SyncSession::*fn)(std::function<void(std::error_code)>))
{
    std::condition_variable cv;
    std::mutex wait_mutex;
    std::atomic<bool> wait_flag(false);
    auto& session = *SyncManager::shared().get_session(realm.config().path, *realm.config().sync_config);
    (session.*fn)([&](auto) {
        wait_flag = true;
        cv.notify_one();
    });
    std::unique_lock<std::mutex> lock(wait_mutex);
    cv.wait(lock, [&]() { return wait_flag == true; });
}

void wait_for_upload(Realm& realm)
{
    wait_for_session(realm, &SyncSession::wait_for_upload_completion);
}

void wait_for_download(Realm& realm)
{
    wait_for_session(realm, &SyncSession::wait_for_download_completion);
}


#endif // REALM_ENABLE_SYNC

#if REALM_HAVE_CLANG_FEATURE(thread_sanitizer)
// A helper which synchronously runs on_change() on a fixed background thread
// so that ThreadSanitizer can potentially detect issues
// This deliberately uses an unsafe spinlock for synchronization to ensure that
// the code being tested has to supply all required safety
static class TsanNotifyWorker {
public:
    TsanNotifyWorker()
    {
        m_thread = std::thread([&] { work(); });
    }

    void work()
    {
        while (true) {
            auto value = m_signal.load(std::memory_order_relaxed);
            if (value == 0 || value == 1)
                continue;
            if (value == 2)
                return;

            if (value & 1) {
                // Synchronize on the first handover of a given coordinator.
                value &= ~1;
                m_signal.load();
            }

            auto c = reinterpret_cast<_impl::RealmCoordinator *>(value);
            c->on_change();
            m_signal.store(1, std::memory_order_relaxed);
        }
    }

    ~TsanNotifyWorker()
    {
        m_signal = 2;
        m_thread.join();
    }

    void on_change(const std::shared_ptr<_impl::RealmCoordinator>& c)
    {
        auto& it = m_published_coordinators[c.get()];
        if (it.lock()) {
            m_signal.store(reinterpret_cast<uintptr_t>(c.get()), std::memory_order_relaxed);
        } else {
            // Synchronize on the first handover of a given coordinator.
            it = c;
            m_signal = reinterpret_cast<uintptr_t>(c.get()) | 1;
        }

        while (m_signal.load(std::memory_order_relaxed) != 1) ;
    }

private:
    std::atomic<uintptr_t> m_signal{0};
    std::thread m_thread;
    std::map<_impl::RealmCoordinator*, std::weak_ptr<_impl::RealmCoordinator>> m_published_coordinators;
} s_worker;

void advance_and_notify(Realm& realm)
{
    s_worker.on_change(_impl::RealmCoordinator::get_existing_coordinator(realm.config().path));
    realm.notify();
}

#else // REALM_HAVE_CLANG_FEATURE(thread_sanitizer)

void advance_and_notify(Realm& realm)
{
    _impl::RealmCoordinator::get_existing_coordinator(realm.config().path)->on_change();
    realm.notify();
}
#endif
