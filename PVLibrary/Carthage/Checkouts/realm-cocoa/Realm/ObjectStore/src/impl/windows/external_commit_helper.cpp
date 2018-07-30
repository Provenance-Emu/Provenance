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

#include "impl/external_commit_helper.hpp"
#include "impl/realm_coordinator.hpp"

#include <algorithm>

using namespace realm;
using namespace realm::_impl;

static std::wstring create_condvar_sharedmemory_name(std::string realm_path) {
    std::replace(realm_path.begin(), realm_path.end(), '\\', '/');
    return L"Local\\Realm_ObjectStore_ExternalCommitHelper_SharedCondVar_" + std::wstring(realm_path.begin(), realm_path.end());
}

ExternalCommitHelper::ExternalCommitHelper(RealmCoordinator& parent)
: m_parent(parent)
, m_condvar_shared(create_condvar_sharedmemory_name(parent.get_path()).c_str())
{
    m_mutex.set_shared_part(InterprocessMutex::SharedPart(), parent.get_path(), "ExternalCommitHelper_ControlMutex");
    m_commit_available.set_shared_part(m_condvar_shared.get(), parent.get_path(),
                                       "ExternalCommitHelper_CommitCondVar",
                                       std::filesystem::temp_directory_path().u8string());
    m_thread = std::async(std::launch::async, [this]() { listen(); });
}

ExternalCommitHelper::~ExternalCommitHelper()
{
    {
        std::lock_guard<InterprocessMutex> lock(m_mutex);
        m_keep_listening = false;
        m_commit_available.notify_all();
    }
    m_thread.wait();

    m_commit_available.release_shared_part();
}

void ExternalCommitHelper::notify_others()
{
    m_commit_available.notify_all();
}

void ExternalCommitHelper::listen()
{
    std::lock_guard<InterprocessMutex> lock(m_mutex);
    while (m_keep_listening) {
        m_commit_available.wait(m_mutex, nullptr);
        if (m_keep_listening) {
			m_parent.on_change();
        }
    }
}
