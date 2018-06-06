/*************************************************************************
 *
 * Copyright 2016 Realm Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 **************************************************************************/

#ifndef REALM_OS_TESTS_UTIL_EVENT_LOOP_HPP
#define REALM_OS_TESTS_UTIL_EVENT_LOOP_HPP

#include <functional>
#include <memory>

namespace realm {
namespace util {

struct EventLoop {
    // Returns if the current platform has an event loop implementation
    static bool has_implementation();

    // Returns the main event loop.
    static EventLoop& main();

    // Run the event loop until the given return predicate returns true
    void run_until(std::function<bool()> predicate);

    // Schedule execution of the given function on the event loop.
    void perform(std::function<void()>);

    EventLoop(EventLoop&&) = default;
    EventLoop& operator=(EventLoop&&) = default;
    ~EventLoop();

private:
    struct Impl;

    EventLoop(std::unique_ptr<Impl>);

    std::unique_ptr<Impl> m_impl;
};

} // namespace util
} // namespace realm

#endif  // REALM_OS_TESTS_UTIL_EVENT_LOOP_HPP
