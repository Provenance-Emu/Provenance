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

#include <realm/link_view_fwd.hpp>

#include <iosfwd>
#include <functional>
#include <memory>
#include <vector>

namespace realm {
    class Table;
    class LinkView;
    class Realm;
    namespace _impl {
        class RealmCoordinator;
    }
}

namespace fuzzer {
struct RealmState {
    realm::Realm& realm;
    realm::_impl::RealmCoordinator& coordinator;

    realm::Table& table;
    realm::LinkViewRef lv;
    int64_t uid;
    std::vector<int64_t> modified;
};

struct CommandFile {
    std::vector<int64_t> initial_values;
    std::vector<size_t> initial_list_indices;
    std::vector<std::function<void (RealmState&)>> commands;

    CommandFile(std::istream& input);

    void import(RealmState& state);
    void run(RealmState& state);
};
}