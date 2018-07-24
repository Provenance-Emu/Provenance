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

#include <utility>
#include <functional>
#include <memory>

namespace realm {
namespace util {

    struct GenericEventLoop {
    public:
        virtual void post(std::function<void()>) = 0;
        virtual ~GenericEventLoop() = default;
        static void set_event_loop_factory(std::function<std::unique_ptr<GenericEventLoop>()>);
        static std::unique_ptr<GenericEventLoop> get();
    };

    template<typename Callback>
    class EventLoopSignal {
    public:
        EventLoopSignal(Callback&& callback)
                : m_callback(std::move(callback))
                , m_eventloop(GenericEventLoop::get())
        { }

        void notify()
        {
            m_eventloop->post(m_callback);
        }
    private:
        Callback m_callback;
        std::unique_ptr<GenericEventLoop> m_eventloop;
    };

} // namespace util
} // namespace realm

