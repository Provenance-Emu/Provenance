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

#include "util/event_loop.hpp"
#include "util/index_helpers.hpp"
#include "util/test_file.hpp"

#include "feature_checks.hpp"
#include "collection_notifications.hpp"
#include "object_accessor.hpp"
#include "property.hpp"
#include "schema.hpp"

#include "impl/realm_coordinator.hpp"
#include "impl/object_accessor_impl.hpp"

#include <realm/group_shared.hpp>
#include <realm/util/any.hpp>

#include <cstdint>

using namespace realm;

namespace {
using AnyDict = std::map<std::string, util::Any>;
using AnyVec = std::vector<util::Any>;
}

struct TestContext : CppContext {
    std::map<std::string, AnyDict> defaults;

    using CppContext::CppContext;
    TestContext(TestContext& parent, realm::Property const& prop)
    : CppContext(parent, prop)
    , defaults(parent.defaults)
    { }

    util::Optional<util::Any>
    default_value_for_property(ObjectSchema const& object, Property const& prop)
    {
        auto obj_it = defaults.find(object.name);
        if (obj_it == defaults.end())
            return util::none;
        auto prop_it = obj_it->second.find(prop.name);
        if (prop_it == obj_it->second.end())
            return util::none;
        return prop_it->second;
    }

    void will_change(Object const&, Property const&) {}
    void did_change() {}
    std::string print(util::Any) { return "not implemented"; }
    bool allow_missing(util::Any) { return false; }
};

TEST_CASE("object") {
    using namespace std::string_literals;
    _impl::RealmCoordinator::assert_no_open_realms();

    InMemoryTestFile config;
    config.automatic_change_notifications = false;
    config.cache = false;
    config.schema = Schema{
        {"table", {
            {"value 1", PropertyType::Int},
            {"value 2", PropertyType::Int},
        }},
        {"all types", {
            {"pk", PropertyType::Int, Property::IsPrimary{true}},
            {"bool", PropertyType::Bool},
            {"int", PropertyType::Int},
            {"float", PropertyType::Float},
            {"double", PropertyType::Double},
            {"string", PropertyType::String},
            {"data", PropertyType::Data},
            {"date", PropertyType::Date},
            {"object", PropertyType::Object|PropertyType::Nullable, "link target"},

            {"bool array", PropertyType::Array|PropertyType::Bool},
            {"int array", PropertyType::Array|PropertyType::Int},
            {"float array", PropertyType::Array|PropertyType::Float},
            {"double array", PropertyType::Array|PropertyType::Double},
            {"string array", PropertyType::Array|PropertyType::String},
            {"data array", PropertyType::Array|PropertyType::Data},
            {"date array", PropertyType::Array|PropertyType::Date},
            {"object array", PropertyType::Array|PropertyType::Object, "array target"},
        }},
        {"all optional types", {
            {"pk", PropertyType::Int|PropertyType::Nullable, Property::IsPrimary{true}},
            {"bool", PropertyType::Bool|PropertyType::Nullable},
            {"int", PropertyType::Int|PropertyType::Nullable},
            {"float", PropertyType::Float|PropertyType::Nullable},
            {"double", PropertyType::Double|PropertyType::Nullable},
            {"string", PropertyType::String|PropertyType::Nullable},
            {"data", PropertyType::Data|PropertyType::Nullable},
            {"date", PropertyType::Date|PropertyType::Nullable},

            {"bool array", PropertyType::Array|PropertyType::Bool|PropertyType::Nullable},
            {"int array", PropertyType::Array|PropertyType::Int|PropertyType::Nullable},
            {"float array", PropertyType::Array|PropertyType::Float|PropertyType::Nullable},
            {"double array", PropertyType::Array|PropertyType::Double|PropertyType::Nullable},
            {"string array", PropertyType::Array|PropertyType::String|PropertyType::Nullable},
            {"data array", PropertyType::Array|PropertyType::Data|PropertyType::Nullable},
            {"date array", PropertyType::Array|PropertyType::Date|PropertyType::Nullable},
        }},
        {"link target", {
            {"value", PropertyType::Int},
        }, {
            {"origin", PropertyType::LinkingObjects|PropertyType::Array, "all types", "object"},
        }},
        {"array target", {
            {"value", PropertyType::Int},
        }},
        {"pk after list", {
            {"array 1", PropertyType::Array|PropertyType::Object, "array target"},
            {"int 1", PropertyType::Int},
            {"pk", PropertyType::Int, Property::IsPrimary{true}},
            {"int 2", PropertyType::Int},
            {"array 2", PropertyType::Array|PropertyType::Object, "array target"},
        }},
        {"nullable int pk", {
            {"pk", PropertyType::Int|PropertyType::Nullable, Property::IsPrimary{true}},
        }},
        {"nullable string pk", {
            {"pk", PropertyType::String|PropertyType::Nullable, Property::IsPrimary{true}},
        }},
        {"person", {
            {"name", PropertyType::String, Property::IsPrimary{true}},
            {"age", PropertyType::Int},
            {"scores", PropertyType::Array|PropertyType::Int},
            {"assistant", PropertyType::Object|PropertyType::Nullable, "person"},
            {"team", PropertyType::Array|PropertyType::Object, "person"},
        }},
    };
    config.schema_version = 0;
    auto r = Realm::get_shared_realm(config);
    auto& coordinator = *_impl::RealmCoordinator::get_existing_coordinator(config.path);

    SECTION("add_notification_callback()") {
        auto table = r->read_group().get_table("class_table");
        r->begin_transaction();

        table->add_empty_row(10);
        for (int i = 0; i < 10; ++i)
            table->set_int(0, i, i);
        r->commit_transaction();

        auto r2 = coordinator.get_realm();

        CollectionChangeSet change;
        Row row = table->get(0);
        Object object(r, *r->schema().find("table"), row);

        auto write = [&](auto&& f) {
            r->begin_transaction();
            f();
            r->commit_transaction();

            advance_and_notify(*r);
        };

        auto require_change = [&] {
            auto token = object.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                change = c;
            });
            advance_and_notify(*r);
            return token;
        };

        auto require_no_change = [&] {
            bool first = true;
            auto token = object.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
                REQUIRE(first);
                first = false;
            });
            advance_and_notify(*r);
            return token;
        };

        SECTION("deleting the object sends a change notification") {
            auto token = require_change();
            write([&] { row.move_last_over(); });
            REQUIRE_INDICES(change.deletions, 0);
        }

        SECTION("modifying the object sends a change notification") {
            auto token = require_change();

            write([&] { row.set_int(0, 10); });
            REQUIRE_INDICES(change.modifications, 0);
            REQUIRE(change.columns.size() == 1);
            REQUIRE_INDICES(change.columns[0], 0);

            write([&] { row.set_int(1, 10); });
            REQUIRE_INDICES(change.modifications, 0);
            REQUIRE(change.columns.size() == 2);
            REQUIRE(change.columns[0].empty());
            REQUIRE_INDICES(change.columns[1], 0);
        }

        SECTION("modifying a different object") {
            auto token = require_no_change();
            write([&] { table->get(1).set_int(0, 10); });
        }

        SECTION("moving the object") {
            auto token = require_no_change();
            write([&] { table->swap_rows(0, 5); });
        }

        SECTION("subsuming the object") {
            auto token = require_change();
            write([&] {
                table->insert_empty_row(0);
                table->merge_rows(row.get_index(), 0);
                row.set_int(0, 10);
            });
            REQUIRE(change.columns.size() == 1);
            REQUIRE_INDICES(change.columns[0], 0);
        }

        SECTION("multiple write transactions") {
            auto token = require_change();

            auto r2row = r2->read_group().get_table("class_table")->get(0);
            r2->begin_transaction();
            r2row.set_int(0, 1);
            r2->commit_transaction();
            r2->begin_transaction();
            r2row.set_int(1, 2);
            r2->commit_transaction();

            advance_and_notify(*r);
            REQUIRE(change.columns.size() == 2);
            REQUIRE_INDICES(change.columns[0], 0);
            REQUIRE_INDICES(change.columns[1], 0);
        }

        SECTION("skipping a notification") {
            auto token = require_no_change();
            write([&] {
                row.set_int(0, 1);
                token.suppress_next();
            });
        }

        SECTION("skipping only effects the current transaction even if no notification would occur anyway") {
            auto token = require_change();

            // would not produce a notification even if it wasn't skipped because no changes were made
            write([&] {
                token.suppress_next();
            });
            REQUIRE(change.empty());

            // should now produce a notification
            write([&] {
                row.set_int(0, 1);
            });
            REQUIRE_INDICES(change.modifications, 0);
        }

        SECTION("add notification callback, remove it, then add another notification callback") {
            {
                auto token = object.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
                    FAIL("This should never happen");
                });
            }
            auto token = require_change();
            write([&] { row.move_last_over(); });
            REQUIRE_INDICES(change.deletions, 0);
        }

        SECTION("observing deleted object throws") {
            write([&] {
                row.move_last_over();
            });
            REQUIRE_THROWS(require_change());
        }
    }

    TestContext d(r);
    auto create = [&](util::Any&& value, bool update, bool update_only_diff = false) {
        r->begin_transaction();
        auto obj = Object::create(d, r, *r->schema().find("all types"), value, update, update_only_diff);
        r->commit_transaction();
        return obj;
    };
    auto create_sub = [&](util::Any&& value, bool update, bool update_only_diff = false) {
        r->begin_transaction();
        auto obj = Object::create(d, r, *r->schema().find("link target"), value, update, update_only_diff);
        r->commit_transaction();
        return obj;
    };
    auto create_company = [&](util::Any&& value, bool update, bool update_only_diff = false) {
        r->begin_transaction();
        auto obj = Object::create(d, r, *r->schema().find("person"), value, update, update_only_diff);
        r->commit_transaction();
        return obj;
    };

    SECTION("create object") {
        auto obj = create(AnyDict{
            {"pk", INT64_C(1)},
            {"bool", true},
            {"int", INT64_C(5)},
            {"float", 2.2f},
            {"double", 3.3},
            {"string", "hello"s},
            {"data", "olleh"s},
            {"date", Timestamp(10, 20)},
            {"object", AnyDict{{"value", INT64_C(10)}}},

            {"bool array", AnyVec{true, false}},
            {"int array", AnyVec{INT64_C(5), INT64_C(6)}},
            {"float array", AnyVec{1.1f, 2.2f}},
            {"double array", AnyVec{3.3, 4.4}},
            {"string array", AnyVec{"a"s, "b"s, "c"s}},
            {"data array", AnyVec{"d"s, "e"s, "f"s}},
            {"date array", AnyVec{}},
            {"object array", AnyVec{AnyDict{{"value", INT64_C(20)}}}},
        }, false);

        auto row = obj.row();
        REQUIRE(row.get_int(0) == 1);
        REQUIRE(row.get_bool(1) == true);
        REQUIRE(row.get_int(2) == 5);
        REQUIRE(row.get_float(3) == 2.2f);
        REQUIRE(row.get_double(4) == 3.3);
        REQUIRE(row.get_string(5) == "hello");
        REQUIRE(row.get_binary(6) == BinaryData("olleh", 5));
        REQUIRE(row.get_timestamp(7) == Timestamp(10, 20));
        REQUIRE(row.get_link(8) == 0);

        auto link_target = r->read_group().get_table("class_link target")->get(0);
        REQUIRE(link_target.get_int(0) == 10);

        auto check_array = [&](size_t col, auto... values) {
            auto table = row.get_subtable(col);
            size_t i = 0;
            for (auto& value : {values...}) {
                CAPTURE(i);
                REQUIRE(i < row.get_subtable_size(col));
                REQUIRE(value == table->get<typename std::decay<decltype(value)>::type>(0, i));
                ++i;
            }
        };
        check_array(9, true, false);
        check_array(10, INT64_C(5), INT64_C(6));
        check_array(11, 1.1f, 2.2f);
        check_array(12, 3.3, 4.4);
        check_array(13, StringData("a"), StringData("b"), StringData("c"));
        check_array(14, BinaryData("d", 1), BinaryData("e", 1), BinaryData("f", 1));

        auto list = row.get_linklist(16);
        REQUIRE(list->size() == 1);
        REQUIRE(list->get(0).get_int(0) == 20);
    }

    SECTION("create uses defaults for missing values") {
        d.defaults["all types"] = {
            {"bool", true},
            {"int", INT64_C(5)},
            {"float", 2.2f},
            {"double", 3.3},
            {"string", "hello"s},
            {"data", "olleh"s},
            {"date", Timestamp(10, 20)},
            {"object", AnyDict{{"value", INT64_C(10)}}},

            {"bool array", AnyVec{true, false}},
            {"int array", AnyVec{INT64_C(5), INT64_C(6)}},
            {"float array", AnyVec{1.1f, 2.2f}},
            {"double array", AnyVec{3.3, 4.4}},
            {"string array", AnyVec{"a"s, "b"s, "c"s}},
            {"data array", AnyVec{"d"s, "e"s, "f"s}},
            {"date array", AnyVec{}},
            {"object array", AnyVec{AnyDict{{"value", INT64_C(20)}}}},
        };

        auto obj = create(AnyDict{
            {"pk", INT64_C(1)},
            {"float", 6.6f},
        }, false);

        auto row = obj.row();
        REQUIRE(row.get_int(0) == 1);
        REQUIRE(row.get_bool(1) == true);
        REQUIRE(row.get_int(2) == 5);
        REQUIRE(row.get_float(3) == 6.6f);
        REQUIRE(row.get_double(4) == 3.3);
        REQUIRE(row.get_string(5) == "hello");
        REQUIRE(row.get_binary(6) == BinaryData("olleh", 5));
        REQUIRE(row.get_timestamp(7) == Timestamp(10, 20));

        REQUIRE(row.get_subtable(9)->size() == 2);
        REQUIRE(row.get_subtable(10)->size() == 2);
        REQUIRE(row.get_subtable(11)->size() == 2);
        REQUIRE(row.get_subtable(12)->size() == 2);
        REQUIRE(row.get_subtable(13)->size() == 3);
        REQUIRE(row.get_subtable(14)->size() == 3);
        REQUIRE(row.get_subtable(15)->size() == 0);
        REQUIRE(row.get_linklist(16)->size() == 1);
    }

    SECTION("create can use defaults for primary key") {
        d.defaults["all types"] = {
            {"pk", INT64_C(10)},
        };
        auto obj = create(AnyDict{
            {"bool", true},
            {"int", INT64_C(5)},
            {"float", 2.2f},
            {"double", 3.3},
            {"string", "hello"s},
            {"data", "olleh"s},
            {"date", Timestamp(10, 20)},
            {"object", AnyDict{{"value", INT64_C(10)}}},
            {"array", AnyVector{AnyDict{{"value", INT64_C(20)}}}},
        }, false);

        auto row = obj.row();
        REQUIRE(row.get_int(0) == 10);
    }

    SECTION("create does not complain about missing values for nullable fields") {
        r->begin_transaction();
        realm::Object obj;
        REQUIRE_NOTHROW(obj = Object::create(d, r, *r->schema().find("all optional types"), util::Any(AnyDict{}), false));
        r->commit_transaction();

        REQUIRE_FALSE(obj.get_property_value<util::Any>(d, "pk").has_value());
        REQUIRE_FALSE(obj.get_property_value<util::Any>(d, "bool").has_value());
        REQUIRE_FALSE(obj.get_property_value<util::Any>(d, "int").has_value());
        REQUIRE_FALSE(obj.get_property_value<util::Any>(d, "float").has_value());
        REQUIRE_FALSE(obj.get_property_value<util::Any>(d, "double").has_value());
        REQUIRE_FALSE(obj.get_property_value<util::Any>(d, "string").has_value());
        REQUIRE_FALSE(obj.get_property_value<util::Any>(d, "data").has_value());
        REQUIRE_FALSE(obj.get_property_value<util::Any>(d, "date").has_value());

        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "bool array")).size() == 0);
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "int array")).size() == 0);
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "float array")).size() == 0);
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "double array")).size() == 0);
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "string array")).size() == 0);
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "data array")).size() == 0);
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "date array")).size() == 0);
    }

    SECTION("create throws for missing values if there is no default") {
        REQUIRE_THROWS(create(AnyDict{
            {"pk", INT64_C(1)},
            {"float", 6.6f},
        }, false));
    }

    SECTION("create always sets the PK first") {
        AnyDict value{
            {"array 1", AnyVector{AnyDict{{"value", INT64_C(1)}}}},
            {"array 2", AnyVector{AnyDict{{"value", INT64_C(2)}}}},
            {"int 1", INT64_C(0)},
            {"int 2", INT64_C(0)},
            {"pk", INT64_C(7)},
        };
        // Core will throw if the list is populated before the PK is set
        r->begin_transaction();
        REQUIRE_NOTHROW(Object::create(d, r, *r->schema().find("pk after list"), util::Any(value), false));
    }

    SECTION("create with update") {
        CollectionChangeSet change;
        bool callback_called;
        Object obj = create(AnyDict{
            {"pk", INT64_C(1)},
            {"bool", true},
            {"int", INT64_C(5)},
            {"float", 2.2f},
            {"double", 3.3},
            {"string", "hello"s},
            {"data", "olleh"s},
            {"date", Timestamp(10, 20)},
            {"object", AnyDict{{"value", INT64_C(10)}}},

            {"bool array", AnyVec{true, false}},
            {"int array", AnyVec{INT64_C(5), INT64_C(6)}},
            {"float array", AnyVec{1.1f, 2.2f}},
            {"double array", AnyVec{3.3, 4.4}},
            {"string array", AnyVec{"a"s, "b"s, "c"s}},
            {"data array", AnyVec{"d"s, "e"s, "f"s}},
            {"date array", AnyVec{}},
            {"object array", AnyVec{AnyDict{{"value", INT64_C(20)}}}},
        }, false);

        auto token = obj.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
            change = c;
            callback_called = true;
        });
        advance_and_notify(*r);

        create(AnyDict{
            {"pk", INT64_C(1)},
            {"int", INT64_C(6)},
            {"string", "a"s},
        }, true);

        callback_called = false;
        advance_and_notify(*r);
        REQUIRE(callback_called);
        REQUIRE_INDICES(change.modifications, 0);

        auto row = obj.row();
        REQUIRE(row.get_int(0) == 1);
        REQUIRE(row.get_bool(1) == true);
        REQUIRE(row.get_int(2) == 6);
        REQUIRE(row.get_float(3) == 2.2f);
        REQUIRE(row.get_double(4) == 3.3);
        REQUIRE(row.get_string(5) == "a");
        REQUIRE(row.get_binary(6) == BinaryData("olleh", 5));
        REQUIRE(row.get_timestamp(7) == Timestamp(10, 20));
    }

    SECTION("create with update - only with diffs") {
        CollectionChangeSet change;
        bool callback_called;
        AnyDict adam {
            {"name", "Adam"s},
            {"age", INT64_C(32)},
            {"scores", AnyVec{INT64_C(1), INT64_C(2)}},
        };
        AnyDict brian {
            {"name", "Brian"s},
            {"age", INT64_C(33)},
        };
        AnyDict charley {
            {"name", "Charley"s},
            {"age", INT64_C(34)},
            {"team", AnyVec{adam, brian}}
        };
        AnyDict donald {
            {"name", "Donald"s},
            {"age", INT64_C(35)},
        };
        AnyDict eddie {
            {"name", "Eddie"s},
            {"age", INT64_C(36)},
            {"assistant", donald},
            {"team", AnyVec{donald, charley}}
        };
        Object obj = create_company(eddie, true);

        auto table = r->read_group().get_table("class_person");
        REQUIRE(table->size() == 5);
        Results result(r, *table);
        auto token = result.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
            change = c;
            callback_called = true;
        });
        advance_and_notify(*r);

        // First update unconditionally
        create_company(eddie, true, false);

        callback_called = false;
        advance_and_notify(*r);
        REQUIRE(callback_called);
        REQUIRE_INDICES(change.modifications, 0, 1, 2, 3, 4);

        // Now, only update where differences (there should not be any diffs - so no update)
        create_company(eddie, true, true);

        REQUIRE(table->size() == 5);
        callback_called = false;
        advance_and_notify(*r);
        REQUIRE(!callback_called);

        // Now, only update sub-object)
        donald["scores"] = AnyVec{INT64_C(3), INT64_C(4), INT64_C(5)};
        // Insert the new donald
        eddie["assistant"] = donald;
        create_company(eddie, true, true);

        REQUIRE(table->size() == 5);
        callback_called = false;
        advance_and_notify(*r);
        REQUIRE(callback_called);
        REQUIRE_INDICES(change.modifications, 1);

        // Shorten list
        donald["scores"] = AnyVec{INT64_C(3), INT64_C(4)};
        eddie["assistant"] = donald;
        create_company(eddie, true, true);

        REQUIRE(table->size() == 5);
        callback_called = false;
        advance_and_notify(*r);
        REQUIRE(callback_called);
        REQUIRE_INDICES(change.modifications, 1);
    }

    SECTION("create with update - identical sub-object") {
        bool callback_called;
        bool sub_callback_called;
        Object sub_obj = create_sub(AnyDict{{"value", INT64_C(10)}}, false);
        Object obj = create(AnyDict{
            {"pk", INT64_C(1)},
            {"bool", true},
            {"int", INT64_C(5)},
            {"float", 2.2f},
            {"double", 3.3},
            {"string", "hello"s},
            {"data", "olleh"s},
            {"date", Timestamp(10, 20)},
            {"object", sub_obj},
        }, false);

        auto token1 = obj.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
            callback_called = true;
        });
        auto token2 = sub_obj.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
            sub_callback_called = true;
        });
        advance_and_notify(*r);

        auto table = r->read_group().get_table("class_link target");
        REQUIRE(table->size() == 1);

        create(AnyDict{
            {"pk", INT64_C(1)},
            {"bool", true},
            {"int", INT64_C(5)},
            {"float", 2.2f},
            {"double", 3.3},
            {"string", "hello"s},
            {"data", "olleh"s},
            {"date", Timestamp(10, 20)},
            {"object", AnyDict{{"value", INT64_C(10)}}},
        }, true, true);

        REQUIRE(table->size() == 1);
        callback_called = false;
        sub_callback_called = false;
        advance_and_notify(*r);
        REQUIRE(!callback_called);
        REQUIRE(!sub_callback_called);

        // Now change sub object
        create(AnyDict{
            {"pk", INT64_C(1)},
            {"bool", true},
            {"int", INT64_C(5)},
            {"float", 2.2f},
            {"double", 3.3},
            {"string", "hello"s},
            {"data", "olleh"s},
            {"date", Timestamp(10, 20)},
            {"object", AnyDict{{"value", INT64_C(11)}}},
        }, true, true);

        callback_called = false;
        sub_callback_called = false;
        advance_and_notify(*r);
        REQUIRE(!callback_called);
        REQUIRE(sub_callback_called);
    }

    SECTION("create with update - identical array of sub-objects") {
        bool callback_called;
        auto dict = AnyDict{
            {"pk", INT64_C(1)},
            {"bool", true},
            {"int", INT64_C(5)},
            {"float", 2.2f},
            {"double", 3.3},
            {"string", "hello"s},
            {"data", "olleh"s},
            {"date", Timestamp(10, 20)},
            {"object array", AnyVec{ AnyDict{{"value", INT64_C(20)}}, AnyDict{{"value", INT64_C(21)}} } },
        };
        Object obj = create(dict, false);

        auto token1 = obj.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
            callback_called = true;
        });
        advance_and_notify(*r);

        create(dict, true, true);

        callback_called = false;
        advance_and_notify(*r);
        REQUIRE(!callback_called);

        // Now change list
        dict["object array"] = AnyVec{AnyDict{{"value", INT64_C(23)}}};
        create(dict, true, true);

        callback_called = false;
        advance_and_notify(*r);
        REQUIRE(callback_called);
    }

    SECTION("set existing fields to null with update") {
        AnyDict initial_values{
            {"pk", INT64_C(1)},
            {"bool", true},
            {"int", INT64_C(5)},
            {"float", 2.2f},
            {"double", 3.3},
            {"string", "hello"s},
            {"data", "olleh"s},
            {"date", Timestamp(10, 20)},

            {"bool array", AnyVec{true, false}},
            {"int array", AnyVec{INT64_C(5), INT64_C(6)}},
            {"float array", AnyVec{1.1f, 2.2f}},
            {"double array", AnyVec{3.3, 4.4}},
            {"string array", AnyVec{"a"s, "b"s, "c"s}},
            {"data array", AnyVec{"d"s, "e"s, "f"s}},
            {"date array", AnyVec{}},
            {"object array", AnyVec{AnyDict{{"value", INT64_C(20)}}}},
        };
        r->begin_transaction();
        auto obj = Object::create(d, r, *r->schema().find("all optional types"), util::Any(initial_values));

        // Missing fields in dictionary do not update anything
        Object::create(d, r, *r->schema().find("all optional types"), util::Any(AnyDict{{"pk", INT64_C(1)}}), true);

        REQUIRE(any_cast<bool>(obj.get_property_value<util::Any>(d, "bool")) == true);
        REQUIRE(any_cast<int64_t>(obj.get_property_value<util::Any>(d, "int")) == 5);
        REQUIRE(any_cast<float>(obj.get_property_value<util::Any>(d, "float")) == 2.2f);
        REQUIRE(any_cast<double>(obj.get_property_value<util::Any>(d, "double")) == 3.3);
        REQUIRE(any_cast<std::string>(obj.get_property_value<util::Any>(d, "string")) == "hello");
        REQUIRE(any_cast<Timestamp>(obj.get_property_value<util::Any>(d, "date")) == Timestamp(10, 20));

        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "bool array")).get<util::Optional<bool>>(0) == true);
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "int array")).get<util::Optional<int64_t>>(0) == 5);
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "float array")).get<util::Optional<float>>(0) == 1.1f);
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "double array")).get<util::Optional<double>>(0) == 3.3);
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "string array")).get<StringData>(0) == "a");
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "date array")).size() == 0);

        AnyDict null_values{
            {"pk", INT64_C(1)},
            {"bool", util::Any()},
            {"int", util::Any()},
            {"float", util::Any()},
            {"double", util::Any()},
            {"string", util::Any()},
            {"data", util::Any()},
            {"date", util::Any()},

            {"bool array", AnyVec{util::Any()}},
            {"int array", AnyVec{util::Any()}},
            {"float array", AnyVec{util::Any()}},
            {"double array", AnyVec{util::Any()}},
            {"string array", AnyVec{util::Any()}},
            {"data array", AnyVec{util::Any()}},
            {"date array", AnyVec{Timestamp()}},
        };
        Object::create(d, r, *r->schema().find("all optional types"), util::Any(null_values), true);

        REQUIRE_FALSE(obj.get_property_value<util::Any>(d, "bool").has_value());
        REQUIRE_FALSE(obj.get_property_value<util::Any>(d, "int").has_value());
        REQUIRE_FALSE(obj.get_property_value<util::Any>(d, "float").has_value());
        REQUIRE_FALSE(obj.get_property_value<util::Any>(d, "double").has_value());
        REQUIRE_FALSE(obj.get_property_value<util::Any>(d, "string").has_value());
        REQUIRE_FALSE(obj.get_property_value<util::Any>(d, "data").has_value());
        REQUIRE_FALSE(obj.get_property_value<util::Any>(d, "date").has_value());

        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "bool array")).get<util::Optional<bool>>(0) == util::none);
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "int array")).get<util::Optional<int64_t>>(0) == util::none);
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "float array")).get<util::Optional<float>>(0) == util::none);
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "double array")).get<util::Optional<double>>(0) == util::none);
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "string array")).get<StringData>(0) == StringData());
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "data array")).get<BinaryData>(0) == BinaryData());
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "date array")).get<Timestamp>(0) == Timestamp());
    }

    SECTION("create throws for duplicate pk if update is not specified") {
        create(AnyDict{
            {"pk", INT64_C(1)},
            {"bool", true},
            {"int", INT64_C(5)},
            {"float", 2.2f},
            {"double", 3.3},
            {"string", "hello"s},
            {"data", "olleh"s},
            {"date", Timestamp(10, 20)},
            {"object", AnyDict{{"value", INT64_C(10)}}},
            {"array", AnyVector{AnyDict{{"value", INT64_C(20)}}}},
        }, false);
        REQUIRE_THROWS(create(AnyDict{
            {"pk", INT64_C(1)},
            {"bool", true},
            {"int", INT64_C(5)},
            {"float", 2.2f},
            {"double", 3.3},
            {"string", "hello"s},
            {"data", "olleh"s},
            {"date", Timestamp(10, 20)},
            {"object", AnyDict{{"value", INT64_C(10)}}},
            {"array", AnyVector{AnyDict{{"value", INT64_C(20)}}}},
        }, false));
    }

    SECTION("create with explicit null pk does not fall back to default") {
        d.defaults["nullable int pk"] = {
            {"pk", INT64_C(10)},
        };
        d.defaults["nullable string pk"] = {
            {"pk", "value"s},
        };
        auto create = [&](util::Any&& value, StringData type) {
            r->begin_transaction();
            auto obj = Object::create(d, r, *r->schema().find(type), value, false);
            r->commit_transaction();
            return obj;
        };

        auto obj = create(AnyDict{{"pk", d.null_value()}}, "nullable int pk");
        REQUIRE(obj.row().is_null(0));
        obj = create(AnyDict{{"pk", d.null_value()}}, "nullable string pk");
        REQUIRE(obj.row().is_null(0));

        obj = create(AnyDict{{}}, "nullable int pk");
        REQUIRE(obj.row().get_int(0) == 10);
        obj = create(AnyDict{{}}, "nullable string pk");
        REQUIRE(obj.row().get_string(0) == "value");
    }

    SECTION("getters and setters") {
        r->begin_transaction();

        auto& table = *r->read_group().get_table("class_all types");
        table.add_empty_row();
        Object obj(r, *r->schema().find("all types"), table[0]);

        auto& link_table = *r->read_group().get_table("class_link target");
        link_table.add_empty_row();
        Object linkobj(r, *r->schema().find("link target"), link_table[0]);

        obj.set_property_value(d, "bool", util::Any(true), false);
        REQUIRE(any_cast<bool>(obj.get_property_value<util::Any>(d, "bool")) == true);

        obj.set_property_value(d, "int", util::Any(INT64_C(5)), false);
        REQUIRE(any_cast<int64_t>(obj.get_property_value<util::Any>(d, "int")) == 5);

        obj.set_property_value(d, "float", util::Any(1.23f), false);
        REQUIRE(any_cast<float>(obj.get_property_value<util::Any>(d, "float")) == 1.23f);

        obj.set_property_value(d, "double", util::Any(1.23), false);
        REQUIRE(any_cast<double>(obj.get_property_value<util::Any>(d, "double")) == 1.23);

        obj.set_property_value(d, "string", util::Any("abc"s), false);
        REQUIRE(any_cast<std::string>(obj.get_property_value<util::Any>(d, "string")) == "abc");

        obj.set_property_value(d, "data", util::Any("abc"s), false);
        REQUIRE(any_cast<std::string>(obj.get_property_value<util::Any>(d, "data")) == "abc");

        obj.set_property_value(d, "date", util::Any(Timestamp(1, 2)), false);
        REQUIRE(any_cast<Timestamp>(obj.get_property_value<util::Any>(d, "date")) == Timestamp(1, 2));

        REQUIRE_FALSE(obj.get_property_value<util::Any>(d, "object").has_value());
        obj.set_property_value(d, "object", util::Any(linkobj), false);
        REQUIRE(any_cast<Object>(obj.get_property_value<util::Any>(d, "object")).row().get_index() == linkobj.row().get_index());

        auto linking = any_cast<Results>(linkobj.get_property_value<util::Any>(d, "origin"));
        REQUIRE(linking.size() == 1);

        REQUIRE_THROWS(obj.set_property_value(d, "pk", util::Any(INT64_C(5)), false));
        REQUIRE_THROWS(obj.set_property_value(d, "not a property", util::Any(INT64_C(5)), false));

        r->commit_transaction();

        REQUIRE_THROWS(obj.get_property_value<util::Any>(d, "not a property"));
        REQUIRE_THROWS(obj.set_property_value(d, "int", util::Any(INT64_C(5)), false));
    }

    SECTION("list property self-assign is a no-op") {
        auto obj = create(AnyDict{
            {"pk", INT64_C(1)},
            {"bool", true},
            {"int", INT64_C(5)},
            {"float", 2.2f},
            {"double", 3.3},
            {"string", "hello"s},
            {"data", "olleh"s},
            {"date", Timestamp(10, 20)},

            {"bool array", AnyVec{true, false}},
            {"object array", AnyVec{AnyDict{{"value", INT64_C(20)}}}},
        }, false);

        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "bool array")).size() == 2);
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "object array")).size() == 1);

        r->begin_transaction();
        obj.set_property_value(d, "bool array", obj.get_property_value<util::Any>(d, "bool array"), false);
        obj.set_property_value(d, "object array", obj.get_property_value<util::Any>(d, "object array"), false);
        r->commit_transaction();

        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "bool array")).size() == 2);
        REQUIRE(any_cast<List&&>(obj.get_property_value<util::Any>(d, "object array")).size() == 1);
    }

#if REALM_ENABLE_SYNC
    if (!util::EventLoop::has_implementation())
        return;

    SyncServer server(false);
    SyncTestFile config1(server, "shared");
    config1.schema = config.schema;
    SyncTestFile config2(server, "shared");
    config2.schema = config.schema;

    SECTION("defaults do not override values explicitly passed to create()") {
        AnyDict v1{
            {"pk", INT64_C(7)},
            {"array 1", AnyVector{AnyDict{{"value", INT64_C(1)}}}},
            {"array 2", AnyVector{AnyDict{{"value", INT64_C(2)}}}},
        };
        auto v2 = v1;
        v1["int 1"] = INT64_C(1);
        v2["int 2"] = INT64_C(2);

        auto r1 = Realm::get_shared_realm(config1);
        auto r2 = Realm::get_shared_realm(config2);

        TestContext c1(r1);
        TestContext c2(r2);

        c1.defaults["pk after list"] = {
            {"int 1", INT64_C(10)},
            {"int 2", INT64_C(10)},
        };
        c2.defaults = c1.defaults;

        r1->begin_transaction();
        r2->begin_transaction();
        auto obj = Object::create(c1, r1, *r1->schema().find("pk after list"), util::Any(v1), false);
        Object::create(c2, r2, *r2->schema().find("pk after list"), util::Any(v2), false);
        r2->commit_transaction();
        r1->commit_transaction();

        server.start();
        util::EventLoop::main().run_until([&] {
            return r1->read_group().get_table("class_array target")->size() == 4;
        });

        // With stable IDs, sync creates the primary key column at index 0.
        REQUIRE(obj.row().get_int(0) == 7); // pk
        REQUIRE(obj.row().get_linklist(1)->size() == 2);
        REQUIRE(obj.row().get_int(2) == 1); // non-default from r1
        REQUIRE(obj.row().get_int(3) == 2); // non-default from r2
        REQUIRE(obj.row().get_linklist(4)->size() == 2);

    }
#endif
}
