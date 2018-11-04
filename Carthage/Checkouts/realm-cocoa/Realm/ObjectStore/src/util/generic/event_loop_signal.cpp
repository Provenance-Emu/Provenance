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

#include "event_loop_signal.hpp"

using namespace realm::util;

struct DummyLoop : public GenericEventLoop {
public:
    void post(std::function<void()>) override {}
};

static std::function<std::unique_ptr<GenericEventLoop>()> s_factory = [] { return std::unique_ptr<GenericEventLoop>(new DummyLoop); };

void GenericEventLoop::set_event_loop_factory(std::function<std::unique_ptr<GenericEventLoop>()> factory)
{
    s_factory = std::move(factory);
}

std::unique_ptr<GenericEventLoop> GenericEventLoop::get()
{
    return s_factory();
}
