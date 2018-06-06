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

#include <realm/group_shared.hpp>

#include <future>
#include <windows.h>

namespace realm {
namespace _impl {
class RealmCoordinator;

namespace win32 {
    template <class T, void (*Initializer)(T&)>
    class SharedMemory {
    public:
        SharedMemory(LPCWSTR name) {
#if REALM_WINDOWS
            HANDLE mapping = CreateFileMappingW(INVALID_HANDLE_VALUE, nullptr, PAGE_READWRITE, 0, sizeof(T), name);
            auto error = GetLastError();
            if (mapping != NULL)
                m_memory = reinterpret_cast<T*>(MapViewOfFile(mapping, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(T)));
#elif REALM_UWP
            HANDLE mapping = CreateFileMappingFromApp(INVALID_HANDLE_VALUE, nullptr, PAGE_READWRITE, sizeof(T), name);
            auto error = GetLastError();
            if (mapping != NULL)
                m_memory = reinterpret_cast<T*>(MapViewOfFileFromApp(mapping, FILE_MAP_ALL_ACCESS, 0, sizeof(T)));
#endif

            if (mapping) {
                // we can close the handle we own because the view has now referenced it
                CloseHandle(mapping);
            }

            try {
                if (error == 0) {
                    Initializer(get());
                }
                else if (error != ERROR_ALREADY_EXISTS) {
                    throw std::system_error(error, std::system_category());
                }
            }
            catch (...) {
                UnmapViewOfFile(m_memory);
                throw;
            }
        }

        T& get() const noexcept { return *m_memory; }

        ~SharedMemory() {
            UnmapViewOfFile(m_memory);
        }
    private:
        T* m_memory = nullptr;
    };
}

class ExternalCommitHelper {
public:
    ExternalCommitHelper(RealmCoordinator& parent);
    ~ExternalCommitHelper();

    void notify_others();

private:
    void listen();

    RealmCoordinator& m_parent;

    // The listener thread
    std::future<void> m_thread;

    win32::SharedMemory<InterprocessCondVar::SharedPart, InterprocessCondVar::init_shared_part> m_condvar_shared;

    InterprocessCondVar m_commit_available;
    InterprocessMutex m_mutex;
    bool m_keep_listening = true;
};

} // namespace _impl
} // namespace realm
