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

#include "catch.hpp"

#include "util/test_file.hpp"

#include "list.hpp"
#include "object.hpp"
#include "object_schema.hpp"
#include "object_store.hpp"
#include "results.hpp"
#include "schema.hpp"
#include "thread_safe_reference.hpp"

#include "impl/object_accessor_impl.hpp"

#include <realm/history.hpp>
#include <realm/util/optional.hpp>

#include <future>
#include <thread>

using namespace realm;

static TableRef get_table(Realm& realm, StringData object_name) {
    return ObjectStore::table_for_object_type(realm.read_group(), object_name);
}

static Object create_object(SharedRealm const& realm, StringData object_type, AnyDict value) {
    CppContext ctx(realm);
    return Object::create(ctx, realm, object_type, util::Any(value));
}

TEST_CASE("thread safe reference") {
    using namespace std::string_literals;

    Schema schema{
        {"foo object", {
            {"ignore me", PropertyType::Int}, // Used in tests cases that don't care about the value.
        }},
        {"string object", {
            {"value", PropertyType::String|PropertyType::Nullable},
        }},
        {"int object", {
            {"value", PropertyType::Int},
        }},
        {"int array object", {
            {"value", PropertyType::Array|PropertyType::Object, "int object"}
        }},
        {"int array", {
            {"value", PropertyType::Array|PropertyType::Int}
        }},
    };

    InMemoryTestFile config;
    config.cache = false;
    config.automatic_change_notifications = false;
    SharedRealm r = Realm::get_shared_realm(config);
    r->update_schema(schema);

    // Convenience object
    r->begin_transaction();
    auto foo = create_object(r, "foo object", {{"ignore me", INT64_C(0)}});
    r->commit_transaction();

    SECTION("disallowed during write transactions") {
        SECTION("obtain") {
            r->begin_transaction();
            REQUIRE_THROWS(r->obtain_thread_safe_reference(foo));
        }
        SECTION("resolve") {
            auto ref = r->obtain_thread_safe_reference(foo);
            r->begin_transaction();
            REQUIRE_THROWS(r->resolve_thread_safe_reference(std::move(ref)));
        }
    }

    SECTION("cleanup properly unpins version") {
        auto history = make_in_realm_history(config.path);
        SharedGroup shared_group(*history, config.options());

        auto get_current_version = [&]() -> VersionID {
            shared_group.begin_read();
            auto version = shared_group.get_version_of_current_transaction();
            shared_group.end_read();
            return version;
        };

        auto reference_version = get_current_version();
        auto ref = util::make_optional(r->obtain_thread_safe_reference(foo));
        r->begin_transaction(); r->commit_transaction(); // Advance version

        REQUIRE(get_current_version() != reference_version); // Ensure advanced
        REQUIRE_NOTHROW(shared_group.begin_read(reference_version)); shared_group.end_read(); // Ensure pinned

        SECTION("destroyed without being resolved") {
            ref = {}; // Destroy thread safe reference, unpinning version
        }
        SECTION("exception thrown on resolve") {
            r->begin_transaction(); // Get into state that'll throw exception on resolve
            REQUIRE_THROWS(r->resolve_thread_safe_reference(std::move(*ref)));
            r->commit_transaction();
        }
        r->begin_transaction(); r->commit_transaction(); // Clean up old versions
        REQUIRE_THROWS(shared_group.begin_read(reference_version)); // Ensure unpinned
    }

    SECTION("version mismatch") {
#ifndef _MSC_VER // Visual C++'s buggy <future> needs its template argument to be default constructible so skip this test
        SECTION("resolves at older version") {
            r->begin_transaction();
            auto num = create_object(r, "int object", {{"value", INT64_C(7)}});
            r->commit_transaction();

            REQUIRE(num.row().get_int(0) == 7);
            auto ref = std::async([config]() -> auto {
                SharedRealm r = Realm::get_shared_realm(config);
                Object num = Object(r, "int object", 0);
                REQUIRE(num.row().get_int(0) == 7);

                r->begin_transaction();
                num.row().set_int(0, 9);
                r->commit_transaction();

                return r->obtain_thread_safe_reference(num);
            }).get();

            REQUIRE(num.row().get_int(0) == 7);
            Object num_prime = r->resolve_thread_safe_reference(std::move(ref));
            REQUIRE(num_prime.row().get_int(0) == 9);
            REQUIRE(num.row().get_int(0) == 9);

            r->begin_transaction();
            num.row().set_int(0, 11);
            r->commit_transaction();

            REQUIRE(num_prime.row().get_int(0) == 11);
            REQUIRE(num.row().get_int(0) == 11);
        }
#endif

        SECTION("resolve at newer version") {
            r->begin_transaction();
            auto num = create_object(r, "int object", {{"value", INT64_C(7)}});
            r->commit_transaction();

            REQUIRE(num.row().get_int(0) == 7);
            auto ref = r->obtain_thread_safe_reference(num);
            std::thread([ref = std::move(ref), config]() mutable {
                SharedRealm r = Realm::get_shared_realm(config);
                Object num = Object(r, "int object", 0);

                r->begin_transaction();
                num.row().set_int(0, 9);
                r->commit_transaction();
                REQUIRE(num.row().get_int(0) == 9);

                Object num_prime = r->resolve_thread_safe_reference(std::move(ref));
                REQUIRE(num_prime.row().get_int(0) == 9);

                r->begin_transaction();
                num_prime.row().set_int(0, 11);
                r->commit_transaction();

                REQUIRE(num.row().get_int(0) == 11);
                REQUIRE(num_prime.row().get_int(0) == 11);
            }).join();

            REQUIRE(num.row().get_int(0) == 7);
            r->refresh();
            REQUIRE(num.row().get_int(0) == 11);
        }

        SECTION("resolve at newer version when schema is specified") {
            r->close();
            config.schema = schema;
            SharedRealm r = Realm::get_shared_realm(config);
            r->begin_transaction();
            auto num = create_object(r, "int object", {{"value", INT64_C(7)}});
            r->commit_transaction();

            auto ref = r->obtain_thread_safe_reference(num);

            r->begin_transaction();
            num.row().set_int(0, 9);
            r->commit_transaction();

            REQUIRE_NOTHROW(r->resolve_thread_safe_reference(std::move(ref)));
        }

        SECTION("resolve references at multiple versions") {
            auto commit_new_num = [&](int64_t value) -> Object {
                r->begin_transaction();
                auto num = create_object(r, "int object", {{"value", value}});
                r->commit_transaction();
                return num;
            };

            auto ref1 = r->obtain_thread_safe_reference(commit_new_num(1));
            auto ref2 = r->obtain_thread_safe_reference(commit_new_num(2));
            std::thread([ref1 = std::move(ref1), ref2 = std::move(ref2), config]() mutable {
                SharedRealm r = Realm::get_shared_realm(config);
                Object num1 = r->resolve_thread_safe_reference(std::move(ref1));
                Object num2 = r->resolve_thread_safe_reference(std::move(ref2));

                REQUIRE(num1.row().get_int(0) == 1);
                REQUIRE(num2.row().get_int(0) == 2);
            }).join();
        }
    }

    SECTION("same thread") {
        r->begin_transaction();
        auto num = create_object(r, "int object", {{"value", INT64_C(7)}});
        r->commit_transaction();

        REQUIRE(num.row().get_int(0) == 7);
        auto ref = r->obtain_thread_safe_reference(num);
        SECTION("same realm") {
            {
                Object num = r->resolve_thread_safe_reference(std::move(ref));
                REQUIRE(num.row().get_int(0) == 7);
                r->begin_transaction();
                num.row().set_int(0, 9);
                r->commit_transaction();
                REQUIRE(num.row().get_int(0) == 9);
            }
            REQUIRE(num.row().get_int(0) == 9);
        }
        SECTION("different realm") {
            {
                SharedRealm r = Realm::get_shared_realm(config);
                Object num = r->resolve_thread_safe_reference(std::move(ref));
                REQUIRE(num.row().get_int(0) == 7);
                r->begin_transaction();
                num.row().set_int(0, 9);
                r->commit_transaction();
                REQUIRE(num.row().get_int(0) == 9);
            }
            REQUIRE(num.row().get_int(0) == 7);
        }
        r->refresh();
        REQUIRE(num.row().get_int(0) == 9);
    }

    SECTION("passing over") {
        SECTION("objects") {
            r->begin_transaction();
            auto str = create_object(r, "string object", {});
            auto num = create_object(r, "int object", {{"value", INT64_C(0)}});
            r->commit_transaction();

            auto ref_str = r->obtain_thread_safe_reference(str);
            auto ref_num = r->obtain_thread_safe_reference(num);
            std::thread([ref_str = std::move(ref_str), ref_num = std::move(ref_num), config]() mutable {
                SharedRealm r = Realm::get_shared_realm(config);
                Object str = r->resolve_thread_safe_reference(std::move(ref_str));
                Object num = r->resolve_thread_safe_reference(std::move(ref_num));

                REQUIRE(str.row().get_string(0).is_null());
                REQUIRE(num.row().get_int(0) == 0);

                r->begin_transaction();
                str.row().set_string(0, "the meaning of life");
                num.row().set_int(0, 42);
                r->commit_transaction();
            }).join();

            REQUIRE(str.row().get_string(0).is_null());
            REQUIRE(num.row().get_int(0) == 0);

            r->refresh();

            REQUIRE(str.row().get_string(0) == "the meaning of life");
            REQUIRE(num.row().get_int(0) == 42);
        }

        SECTION("object list") {
            r->begin_transaction();
            auto zero = create_object(r, "int object", {{"value", INT64_C(0)}});
            create_object(r, "int array object", {{"value", AnyVector{zero}}});
            List list(r, *get_table(*r, "int array object"), 0, 0);
            r->commit_transaction();

            REQUIRE(list.size() == 1);
            REQUIRE(list.get(0).get_int(0) == 0);
            auto ref = r->obtain_thread_safe_reference(list);
            std::thread([ref = std::move(ref), config]() mutable {
                SharedRealm r = Realm::get_shared_realm(config);
                List list = r->resolve_thread_safe_reference(std::move(ref));
                REQUIRE(list.size() == 1);
                REQUIRE(list.get(0).get_int(0) == 0);

                r->begin_transaction();
                list.remove_all();
                auto one = create_object(r, "int object", {{"value", INT64_C(1)}});
                auto two = create_object(r, "int object", {{"value", INT64_C(2)}});
                list.add(one.row());
                list.add(two.row());
                r->commit_transaction();

                REQUIRE(list.size() == 2);
                REQUIRE(list.get(0).get_int(0) == 1);
                REQUIRE(list.get(1).get_int(0) == 2);
            }).join();

            REQUIRE(list.size() == 1);
            REQUIRE(list.get(0).get_int(0) == 0);

            r->refresh();

            REQUIRE(list.size() == 2);
            REQUIRE(list.get(0).get_int(0) == 1);
            REQUIRE(list.get(1).get_int(0) == 2);
        }

        SECTION("sorted object results") {
            auto& table = *get_table(*r, "string object");
            auto results = Results(r, table.where().not_equal(0, "C")).sort({table, {{0}}, {false}});

            r->begin_transaction();
            create_object(r, "string object", {{"value", "A"s}});
            create_object(r, "string object", {{"value", "B"s}});
            create_object(r, "string object", {{"value", "C"s}});
            create_object(r, "string object", {{"value", "D"s}});
            r->commit_transaction();

            REQUIRE(results.size() == 3);
            REQUIRE(results.get(0).get_string(0) == "D");
            REQUIRE(results.get(1).get_string(0) == "B");
            REQUIRE(results.get(2).get_string(0) == "A");
            auto ref = r->obtain_thread_safe_reference(results);
            std::thread([ref = std::move(ref), config]() mutable {
                SharedRealm r = Realm::get_shared_realm(config);
                Results results = r->resolve_thread_safe_reference(std::move(ref));

                REQUIRE(results.size() == 3);
                REQUIRE(results.get(0).get_string(0) == "D");
                REQUIRE(results.get(1).get_string(0) == "B");
                REQUIRE(results.get(2).get_string(0) == "A");

                r->begin_transaction();
                results.get(2).move_last_over();
                results.get(0).move_last_over();
                create_object(r, "string object", {{"value", "E"s}});
                r->commit_transaction();

                REQUIRE(results.size() == 2);
                REQUIRE(results.get(0).get_string(0) == "E");
                REQUIRE(results.get(1).get_string(0) == "B");
            }).join();

            REQUIRE(results.size() == 3);
            REQUIRE(results.get(0).get_string(0) == "D");
            REQUIRE(results.get(1).get_string(0) == "B");
            REQUIRE(results.get(2).get_string(0) == "A");

            r->refresh();

            REQUIRE(results.size() == 2);
            REQUIRE(results.get(0).get_string(0) == "E");
            REQUIRE(results.get(1).get_string(0) == "B");
        }

        SECTION("distinct object results") {
            auto& table = *get_table(*r, "string object");
            auto results = Results(r, table.where()).distinct({table, {{0}}}).sort({{"value", true}});

            r->begin_transaction();
            create_object(r, "string object", {{"value", "A"s}});
            create_object(r, "string object", {{"value", "A"s}});
            create_object(r, "string object", {{"value", "B"s}});
            r->commit_transaction();

            REQUIRE(results.size() == 2);
            REQUIRE(results.get(0).get_string(0) == "A");
            REQUIRE(results.get(1).get_string(0) == "B");
            auto ref = r->obtain_thread_safe_reference(results);
            std::thread([ref = std::move(ref), config]() mutable {
                SharedRealm r = Realm::get_shared_realm(config);
                Results results = r->resolve_thread_safe_reference(std::move(ref));

                REQUIRE(results.size() == 2);
                REQUIRE(results.get(0).get_string(0) == "A");
                REQUIRE(results.get(1).get_string(0) == "B");

                r->begin_transaction();
                results.get(0).move_last_over();
                create_object(r, "string object", {{"value", "C"s}});
                r->commit_transaction();

                REQUIRE(results.size() == 3);
                REQUIRE(results.get(0).get_string(0) == "A");
                REQUIRE(results.get(1).get_string(0) == "B");
                REQUIRE(results.get(2).get_string(0) == "C");
            }).join();

            REQUIRE(results.size() == 2);
            REQUIRE(results.get(0).get_string(0) == "A");
            REQUIRE(results.get(1).get_string(0) == "B");

            r->refresh();

            REQUIRE(results.size() == 3);
            REQUIRE(results.get(0).get_string(0) == "A");
            REQUIRE(results.get(1).get_string(0) == "B");
            REQUIRE(results.get(2).get_string(0) == "C");
        }

        SECTION("int list") {
            r->begin_transaction();
            create_object(r, "int array", {{"value", AnyVector{INT64_C(0)}}});
            List list(r, *get_table(*r, "int array"), 0, 0);
            r->commit_transaction();

            auto ref = r->obtain_thread_safe_reference(list);
            std::thread([ref = std::move(ref), config]() mutable {
                SharedRealm r = Realm::get_shared_realm(config);
                List list = r->resolve_thread_safe_reference(std::move(ref));
                REQUIRE(list.size() == 1);
                REQUIRE(list.get<int64_t>(0) == 0);

                r->begin_transaction();
                list.remove_all();
                list.add(1);
                list.add(2);
                r->commit_transaction();

                REQUIRE(list.size() == 2);
                REQUIRE(list.get<int64_t>(0) == 1);
                REQUIRE(list.get<int64_t>(1) == 2);
            }).join();

            REQUIRE(list.size() == 1);
            REQUIRE(list.get<int64_t>(0) == 0);

            r->refresh();

            REQUIRE(list.size() == 2);
            REQUIRE(list.get<int64_t>(0) == 1);
            REQUIRE(list.get<int64_t>(1) == 2);
        }

        SECTION("sorted int results") {
            r->begin_transaction();
            create_object(r, "int array", {{"value", AnyVector{INT64_C(0), INT64_C(2), INT64_C(1)}}});
            List list(r, *get_table(*r, "int array"), 0, 0);
            r->commit_transaction();

            auto results = list.sort({{"self", true}});

            REQUIRE(results.size() == 3);
            REQUIRE(results.get<int64_t>(0) == 0);
            REQUIRE(results.get<int64_t>(1) == 1);
            REQUIRE(results.get<int64_t>(2) == 2);
            auto ref = r->obtain_thread_safe_reference(results);
            std::thread([ref = std::move(ref), config]() mutable {
                SharedRealm r = Realm::get_shared_realm(config);
                Results results = r->resolve_thread_safe_reference(std::move(ref));

                REQUIRE(results.size() == 3);
                REQUIRE(results.get<int64_t>(0) == 0);
                REQUIRE(results.get<int64_t>(1) == 1);
                REQUIRE(results.get<int64_t>(2) == 2);

                r->begin_transaction();
                List list(r, *get_table(*r, "int array"), 0, 0);
                list.remove(1);
                list.add(-1);
                r->commit_transaction();

                REQUIRE(results.size() == 3);
                REQUIRE(results.get<int64_t>(0) == -1);
                REQUIRE(results.get<int64_t>(1) == 0);
                REQUIRE(results.get<int64_t>(2) == 1);
            }).join();

            REQUIRE(results.size() == 3);
            REQUIRE(results.get<int64_t>(0) == 0);
            REQUIRE(results.get<int64_t>(1) == 1);
            REQUIRE(results.get<int64_t>(2) == 2);

            r->refresh();

            REQUIRE(results.size() == 3);
            REQUIRE(results.get<int64_t>(0) == -1);
            REQUIRE(results.get<int64_t>(1) == 0);
            REQUIRE(results.get<int64_t>(2) == 1);
        }

        SECTION("distinct int results") {
            r->begin_transaction();
            create_object(r, "int array", {{"value", AnyVector{INT64_C(3), INT64_C(2), INT64_C(1), INT64_C(1), INT64_C(2)}}});
            List list(r, *get_table(*r, "int array"), 0, 0);
            r->commit_transaction();

            auto& table = *get_table(*r, "string object");
            auto results = list.as_results().distinct({"self"}).sort({{"self", true}});

            REQUIRE(results.size() == 3);
            REQUIRE(results.get<int64_t>(0) == 1);
            REQUIRE(results.get<int64_t>(1) == 2);
            REQUIRE(results.get<int64_t>(2) == 3);

            auto ref = r->obtain_thread_safe_reference(results);
            std::thread([ref = std::move(ref), config]() mutable {
                SharedRealm r = Realm::get_shared_realm(config);
                Results results = r->resolve_thread_safe_reference(std::move(ref));

                REQUIRE(results.size() == 3);
                REQUIRE(results.get<int64_t>(0) == 1);
                REQUIRE(results.get<int64_t>(1) == 2);
                REQUIRE(results.get<int64_t>(2) == 3);

                r->begin_transaction();
                List list(r, *get_table(*r, "int array"), 0, 0);
                list.remove(1);
                list.remove(0);
                r->commit_transaction();

                REQUIRE(results.size() == 2);
                REQUIRE(results.get<int64_t>(0) == 1);
                REQUIRE(results.get<int64_t>(1) == 2);
            }).join();

            REQUIRE(results.size() == 3);
            REQUIRE(results.get<int64_t>(0) == 1);
            REQUIRE(results.get<int64_t>(1) == 2);
            REQUIRE(results.get<int64_t>(2) == 3);

            r->refresh();

            REQUIRE(results.size() == 2);
            REQUIRE(results.get<int64_t>(0) == 1);
            REQUIRE(results.get<int64_t>(1) == 2);
        }

        SECTION("multiple types") {
            auto results = Results(r, get_table(*r, "int object")->where().equal(0, 5));

            r->begin_transaction();
            auto num = create_object(r, "int object", {{"value", INT64_C(5)}});
            create_object(r, "int array object", {{"value", AnyVector{}}});
            List list(r, *get_table(*r, "int array object"), 0, 0);
            r->commit_transaction();

            REQUIRE(list.size() == 0);
            REQUIRE(results.size() == 1);
            REQUIRE(results.get(0).get_int(0) == 5);
            auto ref_num = r->obtain_thread_safe_reference(num);
            auto ref_list = r->obtain_thread_safe_reference(list);
            auto ref_results = r->obtain_thread_safe_reference(results);
            std::thread([ref_num = std::move(ref_num), ref_list = std::move(ref_list),
                         ref_results = std::move(ref_results), config]() mutable {
                SharedRealm r = Realm::get_shared_realm(config);
                Object num = r->resolve_thread_safe_reference(std::move(ref_num));
                List list = r->resolve_thread_safe_reference(std::move(ref_list));
                Results results = r->resolve_thread_safe_reference(std::move(ref_results));

                REQUIRE(list.size() == 0);
                REQUIRE(results.size() == 1);
                REQUIRE(results.get(0).get_int(0) == 5);

                r->begin_transaction();
                num.row().set_int(0, 6);
                list.add(num.row().get_index());
                r->commit_transaction();

                REQUIRE(list.size() == 1);
                REQUIRE(list.get(0).get_int(0) == 6);
                REQUIRE(results.size() == 0);
            }).join();

            REQUIRE(list.size() == 0);
            REQUIRE(results.size() == 1);
            REQUIRE(results.get(0).get_int(0) == 5);

            r->refresh();

            REQUIRE(list.size() == 1);
            REQUIRE(list.get(0).get_int(0) == 6);
            REQUIRE(results.size() == 0);
        }
    }

    SECTION("resolve at version where handed over thing has been deleted") {
        Object obj;
        auto delete_and_resolve = [&](auto&& list) {
            auto ref = r->obtain_thread_safe_reference(list);

            r->begin_transaction();
            obj.row().move_last_over();
            r->commit_transaction();

            return r->resolve_thread_safe_reference(std::move(ref));
        };

        SECTION("object") {
            r->begin_transaction();
            obj = create_object(r, "int object", {{"value", INT64_C(7)}});
            r->commit_transaction();

            REQUIRE(!delete_and_resolve(obj).is_valid());
        }

        SECTION("object list") {
            r->begin_transaction();
            obj = create_object(r, "int array object", {{"value", AnyVector{AnyDict{{"value", INT64_C(0)}}}}});
            List list(r, *get_table(*r, "int array object"), 0, 0);
            r->commit_transaction();

            REQUIRE(!delete_and_resolve(list).is_valid());
        }

        SECTION("int list") {
            r->begin_transaction();
            obj = create_object(r, "int array", {{"value", AnyVector{INT64_C(1)}}});
            List list(r, *get_table(*r, "int array"), 0, 0);
            r->commit_transaction();

            REQUIRE(!delete_and_resolve(list).is_valid());
        }

        SECTION("object results") {
            r->begin_transaction();
            obj = create_object(r, "int array object", {{"value", AnyVector{AnyDict{{"value", INT64_C(0)}}}}});
            List list(r, *get_table(*r, "int array object"), 0, 0);
            r->commit_transaction();

            auto results = delete_and_resolve(list.sort({{"value", true}}));
            REQUIRE(results.is_valid());
            REQUIRE(results.size() == 0);
        }

        SECTION("int results") {
            r->begin_transaction();
            obj = create_object(r, "int array", {{"value", AnyVector{INT64_C(1)}}});
            List list(r, *get_table(*r, "int array"), 0, 0);
            r->commit_transaction();

            auto results = delete_and_resolve(list.sort({{"self", true}}));
            REQUIRE(results.is_valid());
            REQUIRE(results.size() == 0);
        }
    }

    SECTION("lifetime") {
        SECTION("retains source realm") { // else version will become unpinned
            auto ref = r->obtain_thread_safe_reference(foo);
            r = nullptr;
            r = Realm::get_shared_realm(config);
            REQUIRE_NOTHROW(r->resolve_thread_safe_reference(std::move(ref)));
        }
    }

    SECTION("metadata") {
        r->begin_transaction();
        auto num = create_object(r, "int object", {{"value", INT64_C(5)}});
        r->commit_transaction();
        REQUIRE(num.get_object_schema().name == "int object");

        auto ref = r->obtain_thread_safe_reference(num);
        std::thread([ref = std::move(ref), config]() mutable {
            SharedRealm r = Realm::get_shared_realm(config);
            Object num = r->resolve_thread_safe_reference(std::move(ref));
            REQUIRE(num.get_object_schema().name == "int object");
        }).join();
    }

    SECTION("disallow multiple resolves") {
        auto ref = r->obtain_thread_safe_reference(foo);
        r->resolve_thread_safe_reference(std::move(ref));
        REQUIRE_THROWS(r->resolve_thread_safe_reference(std::move(ref)));
    }
}
