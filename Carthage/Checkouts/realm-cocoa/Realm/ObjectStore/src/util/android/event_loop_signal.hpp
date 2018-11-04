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

#include <algorithm>
#include <memory>
#include <mutex>
#include <shared_mutex>
#include <vector>

#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <android/log.h>
#include <android/looper.h>

#define LOGE(...) do { \
    fprintf(stderr, __VA_ARGS__); \
    __android_log_print(ANDROID_LOG_ERROR, "REALM", __VA_ARGS__); \
} while (0)

namespace realm {
namespace util {
template<typename Callback>
class EventLoopSignal : public std::enable_shared_from_this<EventLoopSignal<Callback>> {
public:
    EventLoopSignal(Callback&& callback)
    : m_callback(std::move(callback)), m_looper(ALooper_forThread()) {
        if (!m_looper) {
            return;
        }
        ALooper_acquire(m_looper);
        // Delay the alooper initialization to the first time notify called.
    }

    ~EventLoopSignal()
    {
        if (!m_looper) {
            return;
        }

        if (inited) {
            ALooper_removeFd(m_looper, m_message_pipe.read);
            ::close(m_message_pipe.write);
            ::close(m_message_pipe.read);
            {
                std::unique_lock<std::shared_timed_mutex> lock(s_mutex);
                s_weak_ptrs.erase(std::remove(s_weak_ptrs.begin(), s_weak_ptrs.end(), &m_weak), s_weak_ptrs.end());
            }
        }
        ALooper_release(m_looper);
    }

    EventLoopSignal(EventLoopSignal&&) = delete;
    EventLoopSignal& operator=(EventLoopSignal&&) = delete;
    EventLoopSignal(EventLoopSignal const&) = delete;
    EventLoopSignal& operator=(EventLoopSignal const&) = delete;

    void notify()
    {
        if (m_looper) {
            init();
            notify_fd(m_message_pipe.write);
        }
    }

private:
    Callback m_callback;
    // Acquire a ref to looper since we may init/destroy in a different thread.
    ALooper* m_looper;
    // weak_ptr points to this.
    std::weak_ptr<EventLoopSignal> m_weak;
    // Flag to avoid checking the weak_ptr.
    bool inited = false;

    // We cannot unregister in the looper callback since it may not be called at all (eg. IntentService).
    // And we have to ensure the looper callback has a valid this pointer to use.
    // To achieve that, a list is used to maintain every weak_ptr to this object, and check if the data in the
    // callback param is in the list.
    static std::vector<std::weak_ptr<EventLoopSignal>*> s_weak_ptrs;
    static std::shared_timed_mutex s_mutex; // shared_mutex is available from C++ 17

    // pipe file descriptor pair we use to signal ALooper
    struct {
      int read = -1;
      int write = -1;
    } m_message_pipe;

    // We need to delay the init to the first time notify since we cannot get the weak_ptr in the contructor.
    inline void init()
    {
        if (inited) {
            return;
        }
        inited = true;

        m_weak = this->shared_from_this();
        {
            std::unique_lock<std::shared_timed_mutex> lock(s_mutex);
            s_weak_ptrs.push_back(&m_weak);
        }

        int message_pipe[2];
        // pipe2 became part of bionic from API 9. But there are some devices with API > 10 that still have problems.
        // See https://github.com/realm/realm-java/issues/3945 .
        if (pipe(message_pipe)) {
            int err = errno;
            LOGE("could not create WeakRealmNotifier ALooper message pipe: %s.", strerror(err));
            return;
        }
        if (fcntl(message_pipe[0], F_SETFL, O_NONBLOCK) == -1 || fcntl(message_pipe[1], F_SETFL, O_NONBLOCK) == -1) {
            int err = errno;
            LOGE("could not set ALooper message pipe non-blocking: %s.", strerror(err));
            // It still works in blocking mode.
        }

        if (ALooper_addFd(m_looper, message_pipe[0], ALOOPER_POLL_CALLBACK,
                          ALOOPER_EVENT_INPUT,
                          &looper_callback, &m_weak) != 1) {
            LOGE("Error adding WeakRealmNotifier callback to looper.");
            ::close(message_pipe[0]);
            ::close(message_pipe[1]);

            return;
        }

        m_message_pipe.read = message_pipe[0];
        m_message_pipe.write = message_pipe[1];
    }

    static int looper_callback(int fd, int events, void* data)
    {
        if ((events & ALOOPER_EVENT_INPUT) != 0) {
            std::shared_ptr<EventLoopSignal> shared;
            {
                std::shared_lock<std::shared_timed_mutex> lock(s_mutex);
                auto weak = static_cast<std::weak_ptr<EventLoopSignal>*>(data);
                if (std::find(s_weak_ptrs.begin(), s_weak_ptrs.end(), weak) != s_weak_ptrs.end()) {
                    // Even if the weak_ptr can be found in the list, the object still can be destroyed in between.
                    // But share_ptr can ensure we either have a valid pointer or the object has gone.
                    shared = weak->lock();
                }
            }
            if (shared) {
                // Clear the buffer. Note that there might be a small chance than more than 1024 bytes left in the pipe,
                // but it is OK. Since we also want to support blocking read here.
                // Clear here instead of in the notify is because of whenever there are bytes left in the pipe, the
                // ALOOPER_EVENT_INPUT will be triggered.
                std::vector<uint8_t> buff(1024);
                read(fd, buff.data(), buff.size());
                // By holding a shared_ptr, this object won't be destroyed in the m_callback.
                shared->m_callback();
            }
        }

        if ((events & ALOOPER_EVENT_HANGUP) != 0) {
            return 0;
        }

        if ((events & ALOOPER_EVENT_ERROR) != 0) {
            LOGE("Unexpected error on WeakRealmNotifier's ALooper message pipe.");
        }

        // return 1 to continue receiving events
        return 1;
    }

    // Write a byte to a pipe to notify anyone waiting for data on the pipe
    static void notify_fd(int write_fd)
    {
        char c = 0;
        ssize_t ret = write(write_fd, &c, 1);
        if (ret == 1) {
            return;
        }

        // If the pipe's buffer is full, ALOOPER_EVENT_INPUT will be triggered anyway. Also the buffer clearing happens
        // before calling the callback. So after this call, the callback will be called. Just return here.
        if (ret != 0) {
            int err = errno;
            if (err != EAGAIN) {
                throw std::system_error(err, std::system_category());
            }
        }
    }
};

template<typename Callback>
std::vector<std::weak_ptr<EventLoopSignal<Callback>>*> EventLoopSignal<Callback>::s_weak_ptrs;
template<typename Callback>
std::shared_timed_mutex EventLoopSignal<Callback>::s_mutex;

} // namespace util
} // namespace realm
