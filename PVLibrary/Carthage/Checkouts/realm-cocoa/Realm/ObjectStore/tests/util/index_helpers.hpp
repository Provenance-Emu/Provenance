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

#define REQUIRE_INDICES(index_set, ...) do { \
    index_set.verify(); \
    std::initializer_list<size_t> expected = {__VA_ARGS__}; \
    auto actual = index_set.as_indexes(); \
    INFO("Checking " #index_set); \
    REQUIRE(expected.size() == static_cast<size_t>(std::distance(actual.begin(), actual.end()))); \
    auto begin = actual.begin(); \
    for (auto index : expected) { \
        REQUIRE(*begin++ == index); \
    } \
} while (0)

#define REQUIRE_COLUMN_INDICES(columns, col, ...) do { \
    REQUIRE((columns).size() > col); \
    REQUIRE_INDICES((columns)[col], __VA_ARGS__); \
} while (0)

#define REQUIRE_MOVES(c, ...) do { \
    auto actual = (c); \
    std::initializer_list<CollectionChangeSet::Move> expected = {__VA_ARGS__}; \
    REQUIRE(expected.size() == actual.moves.size()); \
    auto begin = actual.moves.begin(); \
    for (auto move : expected) { \
        CHECK(begin->from == move.from); \
        CHECK(begin->to == move.to); \
        ++begin; \
    } \
} while (0)
