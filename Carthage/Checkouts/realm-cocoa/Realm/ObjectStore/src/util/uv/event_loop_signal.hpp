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

#include <atomic>
#include <uv.h>

namespace realm {
namespace util {
template<typename Callback>
class EventLoopSignal {
public:
    struct Data {
        Callback callback;
        std::atomic<bool> close_requested;
    };

    EventLoopSignal(Callback&& callback)
    {
        m_handle->data = new Data { std::move(callback), {false} };

        // This assumes that only one thread matters: the main thread (default loop).
        uv_async_init(uv_default_loop(), m_handle, [](uv_async_t* handle) {
            auto& data = *static_cast<Data*>(handle->data);
            if (data.close_requested) {
                uv_close(reinterpret_cast<uv_handle_t*>(handle), [](uv_handle_t* handle) {
                    delete reinterpret_cast<Data*>(handle->data);
                    delete reinterpret_cast<uv_async_t*>(handle);
                });
            } else {
                data.callback();
            }
        });
    }

    ~EventLoopSignal()
    {
        static_cast<Data*>(m_handle->data)->close_requested = true;
        uv_async_send(m_handle);
    }

    EventLoopSignal(EventLoopSignal&&) = delete;
    EventLoopSignal& operator=(EventLoopSignal&&) = delete;
    EventLoopSignal(EventLoopSignal const&) = delete;
    EventLoopSignal& operator=(EventLoopSignal const&) = delete;

    void notify()
    {
        uv_async_send(m_handle);
    }

private:
    uv_async_t* m_handle = new uv_async_t;
};
} // namespace util
} // namespace realm
