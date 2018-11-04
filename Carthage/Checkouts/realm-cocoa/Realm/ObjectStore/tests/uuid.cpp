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

#include "util/uuid.hpp"

#include <algorithm>
#include <cctype>

using namespace realm;

TEST_CASE("uuid") {
    auto isxdigit = [](char c) { return std::isxdigit(c); };

    auto uuid = util::uuid_string();
    INFO("uuid: " << uuid);

    CHECK(uuid.size() == 36);

    // Version 4.
    CHECK(uuid[14] == '4');
    // Variant 1 (IETF).
    CHECK((uuid[19] == '8' || uuid[19] == '9' || uuid[19] == 'a' || uuid[19] == 'b'));

    CHECK(std::all_of(&uuid[0], &uuid[8], isxdigit));
    CHECK(uuid[8] == '-');
    CHECK(std::all_of(&uuid[9], &uuid[13], isxdigit));
    CHECK(uuid[13] == '-');
    CHECK(std::all_of(&uuid[14], &uuid[18], isxdigit));
    CHECK(uuid[18] == '-');
    CHECK(std::all_of(&uuid[19], &uuid[23], isxdigit));
    CHECK(uuid[23] == '-');
    CHECK(std::all_of(&uuid[24], &uuid[36], isxdigit));
}
