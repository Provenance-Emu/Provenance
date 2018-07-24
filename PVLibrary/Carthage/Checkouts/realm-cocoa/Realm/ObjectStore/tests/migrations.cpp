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

#include "object_schema.hpp"
#include "object_store.hpp"
#include "property.hpp"
#include "schema.hpp"

#include "impl/object_accessor_impl.hpp"

#include <realm/descriptor.hpp>
#include <realm/group.hpp>
#include <realm/table.hpp>
#include <realm/util/scope_exit.hpp>

#ifdef _WIN32
#include <Windows.h>
#endif

using namespace realm;

#define VERIFY_SCHEMA(r) verify_schema((r), __LINE__)

#define REQUIRE_UPDATE_SUCCEEDS(r, s, version) do { \
    REQUIRE_NOTHROW((r).update_schema(s, version)); \
    VERIFY_SCHEMA(r); \
    REQUIRE((r).schema() == s); \
} while (0)

#define REQUIRE_NO_MIGRATION_NEEDED(r, schema1, schema2) do { \
    REQUIRE_UPDATE_SUCCEEDS(r, schema1, 0); \
    REQUIRE_UPDATE_SUCCEEDS(r, schema2, 0); \
} while (0)

#define REQUIRE_MIGRATION_NEEDED(r, schema1, schema2) do { \
    REQUIRE_UPDATE_SUCCEEDS(r, schema1, 0); \
    REQUIRE_THROWS((r).update_schema(schema2)); \
    REQUIRE((r).schema() == schema1); \
    REQUIRE_UPDATE_SUCCEEDS(r, schema2, 1); \
} while (0)

namespace {
void verify_schema(Realm& r, int line)
{
    CAPTURE(line);
    for (auto&& object_schema : r.schema()) {
        auto table = ObjectStore::table_for_object_type(r.read_group(), object_schema.name);
        REQUIRE(table);
        CAPTURE(object_schema.name)
        std::string primary_key = ObjectStore::get_primary_key_for_object(r.read_group(), object_schema.name);
        REQUIRE(primary_key == object_schema.primary_key);
        for (auto&& prop : object_schema.persisted_properties) {
            size_t col = table->get_column_index(prop.name);
            CAPTURE(prop.name)
            REQUIRE(col != npos);
            REQUIRE(col == prop.table_column);
            REQUIRE(to_underlying(ObjectSchema::from_core_type(*table->get_descriptor(), col)) ==
                    to_underlying(prop.type));
            REQUIRE(table->has_search_index(col) == prop.requires_index());
            REQUIRE(bool(prop.is_primary) == (prop.name == primary_key));
        }
    }
}

TableRef get_table(std::shared_ptr<Realm> const& realm, StringData object_type)
{
    return ObjectStore::table_for_object_type(realm->read_group(), object_type);
}

// Helper functions for modifying Schema objects, mostly for the sake of making
// it clear what exactly is different about the 2+ schema objects used in
// various tests
Schema add_table(Schema const& schema, ObjectSchema object_schema)
{
    std::vector<ObjectSchema> new_schema(schema.begin(), schema.end());
    new_schema.push_back(std::move(object_schema));
    return new_schema;
}

Schema remove_table(Schema const& schema, StringData object_name)
{
    std::vector<ObjectSchema> new_schema;
    std::remove_copy_if(schema.begin(), schema.end(), std::back_inserter(new_schema),
                        [&](auto&& object_schema) { return object_schema.name == object_name; });
    return new_schema;
}

Schema add_property(Schema schema, StringData object_name, Property property)
{
    schema.find(object_name)->persisted_properties.push_back(std::move(property));
    return schema;
}

Schema remove_property(Schema schema, StringData object_name, StringData property_name)
{
    auto& properties = schema.find(object_name)->persisted_properties;
    properties.erase(find_if(begin(properties), end(properties),
                             [&](auto&& prop) { return prop.name == property_name; }));
    return schema;
}

Schema set_indexed(Schema schema, StringData object_name, StringData property_name, bool value)
{
    schema.find(object_name)->property_for_name(property_name)->is_indexed = value;
    return schema;
}

Schema set_optional(Schema schema, StringData object_name, StringData property_name, bool value)
{
    auto& prop = *schema.find(object_name)->property_for_name(property_name);
    if (value)
        prop.type |= PropertyType::Nullable;
    else
        prop.type &= ~PropertyType::Nullable;
    return schema;
}

Schema set_type(Schema schema, StringData object_name, StringData property_name, PropertyType value)
{
    schema.find(object_name)->property_for_name(property_name)->type = value;
    return schema;
}

Schema set_target(Schema schema, StringData object_name, StringData property_name, StringData new_target)
{
    schema.find(object_name)->property_for_name(property_name)->object_type = new_target;
    return schema;
}

Schema set_primary_key(Schema schema, StringData object_name, StringData new_primary_property)
{
    auto& object_schema = *schema.find(object_name);
    if (auto old_primary = object_schema.primary_key_property()) {
        old_primary->is_primary = false;
    }
    if (new_primary_property.size()) {
        object_schema.property_for_name(new_primary_property)->is_primary = true;
    }
    object_schema.primary_key = new_primary_property;
    return schema;
}
} // anonymous namespace

TEST_CASE("migration: Automatic") {
    InMemoryTestFile config;
    config.automatic_change_notifications = false;

    SECTION("no migration required") {
        SECTION("add object schema") {
            auto realm = Realm::get_shared_realm(config);

            Schema schema1 = {};
            Schema schema2 = add_table(schema1, {"object", {
                {"value", PropertyType::Int}
            }});
            Schema schema3 = add_table(schema2, {"object2", {
                {"value", PropertyType::Int}
            }});
            REQUIRE_UPDATE_SUCCEEDS(*realm, schema1, 0);
            REQUIRE_UPDATE_SUCCEEDS(*realm, schema2, 0);
            REQUIRE_UPDATE_SUCCEEDS(*realm, schema3, 0);
        }

        SECTION("remove object schema") {
            auto realm = Realm::get_shared_realm(config);

            Schema schema1 = {
                {"object", {
                    {"value", PropertyType::Int}
                }},
                {"object2", {
                    {"value", PropertyType::Int}
                }},
            };
            Schema schema2 = remove_table(schema1, "object2");
            Schema schema3 = remove_table(schema2, "object");
            REQUIRE_UPDATE_SUCCEEDS(*realm, schema3, 0);
            REQUIRE_UPDATE_SUCCEEDS(*realm, schema2, 0);
            REQUIRE_UPDATE_SUCCEEDS(*realm, schema1, 0);
        }

        SECTION("add index") {
            auto realm = Realm::get_shared_realm(config);
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int}
                }},
            };
            REQUIRE_NO_MIGRATION_NEEDED(*realm, schema, set_indexed(schema, "object", "value", true));
        }

        SECTION("remove index") {
            auto realm = Realm::get_shared_realm(config);
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int, Property::IsPrimary{false}, Property::IsIndexed{true}}
                }},
            };
            REQUIRE_NO_MIGRATION_NEEDED(*realm, schema, set_indexed(schema, "object", "value", false));
        }

        SECTION("reordering properties") {
            auto realm = Realm::get_shared_realm(config);

            Schema schema1 = {
                {"object", {
                    {"col1", PropertyType::Int},
                    {"col2", PropertyType::Int},
                }},
            };
            Schema schema2 = {
                {"object", {
                    {"col2", PropertyType::Int},
                    {"col1", PropertyType::Int},
                }},
            };
            REQUIRE_NO_MIGRATION_NEEDED(*realm, schema1, schema2);
        }
    }

    SECTION("migration required") {
        SECTION("add property to existing object schema") {
            auto realm = Realm::get_shared_realm(config);

            Schema schema1 = {
                {"object", {
                    {"col1", PropertyType::Int},
                }},
            };
            auto schema2 = add_property(schema1, "object",
                                        {"col2", PropertyType::Int});
            REQUIRE_MIGRATION_NEEDED(*realm, schema1, schema2);
        }

        SECTION("remove property from existing object schema") {
            auto realm = Realm::get_shared_realm(config);
            Schema schema = {
                {"object", {
                    {"col1", PropertyType::Int},
                    {"col2", PropertyType::Int},
                }},
            };
            REQUIRE_MIGRATION_NEEDED(*realm, schema, remove_property(schema, "object", "col2"));
        }

        SECTION("migratation which replaces a persisted property with a computed one") {
            auto realm = Realm::get_shared_realm(config);
            Schema schema1 = {
                {"object", {
                    {"value", PropertyType::Int},
                    {"link", PropertyType::Object|PropertyType::Nullable, "object2"},
                }},
                {"object2", {
                    {"value", PropertyType::Int},
                    {"inverse", PropertyType::Object|PropertyType::Nullable, "object"},
                }},
            };
            Schema schema2 = remove_property(schema1, "object", "link");
            Property new_property{"link", PropertyType::LinkingObjects|PropertyType::Array, "object2", "inverse"};
            schema2.find("object")->computed_properties.emplace_back(new_property);

            REQUIRE_UPDATE_SUCCEEDS(*realm, schema1, 0);
            REQUIRE_THROWS((*realm).update_schema(schema2));
            REQUIRE((*realm).schema() == schema1);
            REQUIRE_NOTHROW((*realm).update_schema(schema2, 1,
                            [](SharedRealm, SharedRealm, Schema&) { /* empty but present migration handler */ }));
            VERIFY_SCHEMA(*realm);
            REQUIRE((*realm).schema() == schema2);
        }

        SECTION("change property type") {
            auto realm = Realm::get_shared_realm(config);
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };
            REQUIRE_MIGRATION_NEEDED(*realm, schema, set_type(schema, "object", "value", PropertyType::Float));
        }

        SECTION("make property nullable") {
            auto realm = Realm::get_shared_realm(config);

            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };
            REQUIRE_MIGRATION_NEEDED(*realm, schema, set_optional(schema, "object", "value", true));
        }

        SECTION("make property required") {
            auto realm = Realm::get_shared_realm(config);

            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int|PropertyType::Nullable},
                }},
            };
            REQUIRE_MIGRATION_NEEDED(*realm, schema, set_optional(schema, "object", "value", false));
        }

        SECTION("change link target") {
            auto realm = Realm::get_shared_realm(config);

            Schema schema = {
                {"target 1", {
                    {"value", PropertyType::Int},
                }},
                {"target 2", {
                    {"value", PropertyType::Int},
                }},
                {"origin", {
                    {"value", PropertyType::Object|PropertyType::Nullable, "target 1"},
                }},
            };
            REQUIRE_MIGRATION_NEEDED(*realm, schema, set_target(schema, "origin", "value", "target 2"));
        }

        SECTION("add pk") {
            auto realm = Realm::get_shared_realm(config);

            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };
            REQUIRE_MIGRATION_NEEDED(*realm, schema, set_primary_key(schema, "object", "value"));
        }

        SECTION("remove pk") {
            auto realm = Realm::get_shared_realm(config);

            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int, Property::IsPrimary{true}},
                }},
            };
            REQUIRE_MIGRATION_NEEDED(*realm, schema, set_primary_key(schema, "object", ""));
        }

        SECTION("adding column and table in same migration doesn't add duplicate columns") {
            auto realm = Realm::get_shared_realm(config);

            Schema schema1 = {
                {"object", {
                    {"col1", PropertyType::Int},
                }},
            };
            auto schema2 = add_table(add_property(schema1, "object", {"col2", PropertyType::Int}),
                                     {"object2", {{"value", PropertyType::Int}}});
            REQUIRE_UPDATE_SUCCEEDS(*realm, schema1, 0);
            REQUIRE_UPDATE_SUCCEEDS(*realm, schema2, 1);

            auto& table = *get_table(realm, "object2");
            REQUIRE(table.get_column_count() == 1);
        }
    }

    SECTION("migration block invocations") {
        SECTION("not called for initial creation of schema") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };
            auto realm = Realm::get_shared_realm(config);
            realm->update_schema(schema, 5, [](SharedRealm, SharedRealm, Schema&) { REQUIRE(false); });
        }

        SECTION("not called when schema version is unchanged even if there are schema changes") {
            Schema schema1 = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };
            Schema schema2 = add_table(schema1, {"second object", {
                {"value", PropertyType::Int},
            }});
            auto realm = Realm::get_shared_realm(config);
            realm->update_schema(schema1, 1);
            realm->update_schema(schema2, 1, [](SharedRealm, SharedRealm, Schema&) { REQUIRE(false); });
        }

        SECTION("called when schema version is bumped even if there are no schema changes") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };
            auto realm = Realm::get_shared_realm(config);
            realm->update_schema(schema);
            bool called = false;
            realm->update_schema(schema, 5, [&](SharedRealm, SharedRealm, Schema&) { called = true; });
            REQUIRE(called);
        }
    }

    SECTION("migration errors") {
        SECTION("schema version cannot go down") {
            auto realm = Realm::get_shared_realm(config);
            realm->update_schema({}, 1);
            realm->update_schema({}, 2);
            REQUIRE_THROWS(realm->update_schema({}, 0));
        }

        SECTION("insert duplicate keys for existing PK during migration") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int, Property::IsPrimary{true}},
                }},
            };
            auto realm = Realm::get_shared_realm(config);
            realm->update_schema(schema, 1);
            REQUIRE_THROWS(realm->update_schema(schema, 2, [](SharedRealm, SharedRealm realm, Schema&) {
                auto table = ObjectStore::table_for_object_type(realm->read_group(), "object");
                table->add_empty_row(2);
            }));
        }

        SECTION("add pk to existing table with duplicate keys") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };
            auto realm = Realm::get_shared_realm(config);
            realm->update_schema(schema, 1);

            auto table = ObjectStore::table_for_object_type(realm->read_group(), "object");
            table->add_empty_row(2);

            schema = set_primary_key(schema, "object", "value");
            REQUIRE_THROWS(realm->update_schema(schema, 2, nullptr));
        }

        SECTION("throwing an exception from migration function rolls back all changes") {
            Schema schema1 = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };
            Schema schema2 = add_property(schema1, "object",
                                          {"value2", PropertyType::Int});
            auto realm = Realm::get_shared_realm(config);
            realm->update_schema(schema1, 1);

            REQUIRE_THROWS(realm->update_schema(schema2, 2, [](SharedRealm, SharedRealm realm, Schema&) {
                auto table = ObjectStore::table_for_object_type(realm->read_group(), "object");
                table->add_empty_row();
                throw 5;
            }));

            auto table = ObjectStore::table_for_object_type(realm->read_group(), "object");
            REQUIRE(table->size() == 0);
            REQUIRE(realm->schema_version() == 1);
            REQUIRE(realm->schema() == schema1);
        }
    }

    SECTION("valid migrations") {
        SECTION("changing all columns does not lose row count") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };
            auto realm = Realm::get_shared_realm(config);
            realm->update_schema(schema, 1);

            realm->begin_transaction();
            auto table = ObjectStore::table_for_object_type(realm->read_group(), "object");
            table->add_empty_row(10);
            realm->commit_transaction();

            schema = set_type(schema, "object", "value", PropertyType::Float);
            realm->update_schema(schema, 2);
            REQUIRE(table->size() == 10);
        }

        SECTION("values for required properties are copied when converitng to nullable") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };
            auto realm = Realm::get_shared_realm(config);
            realm->update_schema(schema, 1);

            realm->begin_transaction();
            auto table = ObjectStore::table_for_object_type(realm->read_group(), "object");
            table->add_empty_row(10);
            for (size_t i = 0; i < 10; ++i)
                table->set_int(0, i, i);
            realm->commit_transaction();

            realm->update_schema(set_optional(schema, "object", "value", true), 2);
            for (int i = 0; i < 10; ++i)
                REQUIRE(table->get_int(0, i) == i);
        }

        SECTION("values for nullable properties are discarded when converitng to required") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int|PropertyType::Nullable},
                }},
            };
            auto realm = Realm::get_shared_realm(config);
            realm->update_schema(schema, 1);

            realm->begin_transaction();
            auto table = ObjectStore::table_for_object_type(realm->read_group(), "object");
            table->add_empty_row(10);
            for (size_t i = 0; i < 10; ++i)
                table->set_int(0, i, i);
            realm->commit_transaction();

            realm->update_schema(set_optional(schema, "object", "value", false), 2);
            for (size_t i = 0; i < 10; ++i)
                REQUIRE(table->get_int(0, i) == 0);
        }

        SECTION("deleting table removed from the schema deletes it") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int|PropertyType::Nullable},
                }},
            };
            auto realm = Realm::get_shared_realm(config);
            realm->update_schema(schema, 1);

            realm->update_schema({}, 2, [](SharedRealm, SharedRealm realm, Schema&) {
                ObjectStore::delete_data_for_object(realm->read_group(), "object");
            });
            REQUIRE_FALSE(ObjectStore::table_for_object_type(realm->read_group(), "object"));
        }

        SECTION("deleting table still in the schema recreates it with no rows") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int|PropertyType::Nullable},
                }},
            };
            auto realm = Realm::get_shared_realm(config);
            realm->update_schema(schema, 1);

            realm->begin_transaction();
            ObjectStore::table_for_object_type(realm->read_group(), "object")->add_empty_row();
            realm->commit_transaction();

            realm->update_schema(schema, 2, [](SharedRealm, SharedRealm realm, Schema&) {
                ObjectStore::delete_data_for_object(realm->read_group(), "object");
            });
            auto table = ObjectStore::table_for_object_type(realm->read_group(), "object");
            REQUIRE(table);
            REQUIRE(table->size() == 0);
        }

        SECTION("deleting table which doesn't exist does nothing") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int|PropertyType::Nullable},
                }},
            };
            auto realm = Realm::get_shared_realm(config);
            realm->update_schema(schema, 1);

            REQUIRE_NOTHROW(realm->update_schema({}, 2, [](SharedRealm, SharedRealm realm, Schema&) {
                ObjectStore::delete_data_for_object(realm->read_group(), "foo");
            }));
        }

        SECTION("subtables columns are not modified by unrelated changes") {
            config.in_memory = false;
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };

            {
                auto realm = Realm::get_shared_realm(config);
                realm->update_schema(schema, 1);
                realm->begin_transaction();
                get_table(realm, "object")->add_column(type_Table, "subtable");
                realm->commit_transaction();
            }
            // close and reopen the Realm to ensure it rereads the schema from
            // the group

            auto realm = Realm::get_shared_realm(config);
            realm->update_schema(add_property(schema, "object", {"value 2", PropertyType::Int}), 2);

            auto& table = *get_table(realm, "object");
            REQUIRE(table.get_column_type(1) == type_Table);
            REQUIRE(table.get_column_count() == 3);
        }
    }

    SECTION("schema correctness during migration") {
        InMemoryTestFile config;
        config.schema_mode = SchemaMode::Automatic;
        auto realm = Realm::get_shared_realm(config);

        Schema schema = {
            {"object", {
                {"pk", PropertyType::Int, Property::IsPrimary{true}},
                {"value", PropertyType::Int, Property::IsPrimary{false}, Property::IsIndexed{true}},
                {"optional", PropertyType::Int|PropertyType::Nullable},
            }},
            {"link origin", {
                {"not a pk", PropertyType::Int},
                {"object", PropertyType::Object|PropertyType::Nullable, "object"},
                {"array", PropertyType::Array|PropertyType::Object, "object"},
            }}
        };
        realm->update_schema(schema);

#define VERIFY_SCHEMA_IN_MIGRATION(target_schema) do { \
    Schema new_schema = (target_schema); \
    realm->update_schema(new_schema, 1, [&](SharedRealm old_realm, SharedRealm new_realm, Schema&) { \
        REQUIRE(old_realm->schema_version() == 0); \
        REQUIRE(old_realm->schema() == schema); \
        REQUIRE(new_realm->schema_version() == 1); \
        REQUIRE(new_realm->schema() == new_schema); \
        VERIFY_SCHEMA(*old_realm); \
        VERIFY_SCHEMA(*new_realm); \
    }); \
    REQUIRE(realm->schema() == new_schema); \
    VERIFY_SCHEMA(*realm); \
} while (false)

        SECTION("add new table") {
            VERIFY_SCHEMA_IN_MIGRATION(add_table(schema, {"new table", {
                {"value", PropertyType::Int},
            }}));
        }
        SECTION("add property to table") {
            VERIFY_SCHEMA_IN_MIGRATION(add_property(schema, "object", {"new", PropertyType::Int}));
        }
        SECTION("remove property from table") {
            VERIFY_SCHEMA_IN_MIGRATION(remove_property(schema, "object", "value"));
        }
        SECTION("remove multiple properties from table") {
            VERIFY_SCHEMA_IN_MIGRATION(remove_property(remove_property(schema, "object", "value"), "object", "optional"));
        }
        SECTION("add primary key to table") {
            VERIFY_SCHEMA_IN_MIGRATION(set_primary_key(schema, "link origin", "not a pk"));
        }
        SECTION("remove primary key from table") {
            VERIFY_SCHEMA_IN_MIGRATION(set_primary_key(schema, "object", ""));
        }
        SECTION("change primary key") {
            VERIFY_SCHEMA_IN_MIGRATION(set_primary_key(schema, "object", "value"));
        }
        SECTION("change property type") {
            VERIFY_SCHEMA_IN_MIGRATION(set_type(schema, "object", "value", PropertyType::Date));
        }
        SECTION("change link target") {
            VERIFY_SCHEMA_IN_MIGRATION(set_target(schema, "link origin", "object", "link origin"));
        }
        SECTION("change linklist target") {
            VERIFY_SCHEMA_IN_MIGRATION(set_target(schema, "link origin", "array", "link origin"));
        }
        SECTION("make property optional") {
            VERIFY_SCHEMA_IN_MIGRATION(set_optional(schema, "object", "value", true));
        }
        SECTION("make property required") {
            VERIFY_SCHEMA_IN_MIGRATION(set_optional(schema, "object", "optional", false));
        }
        SECTION("add index") {
            VERIFY_SCHEMA_IN_MIGRATION(set_indexed(schema, "object", "optional", true));
        }
        SECTION("remove index") {
            VERIFY_SCHEMA_IN_MIGRATION(set_indexed(schema, "object", "value", false));
        }
        SECTION("reorder properties") {
            auto schema2 = schema;
            auto& properties = schema2.find("object")->persisted_properties;
            std::swap(properties[0], properties[1]);
            VERIFY_SCHEMA_IN_MIGRATION(schema2);
        }
    }

    SECTION("object accessors inside migrations") {
        using namespace std::string_literals;

        Schema schema{
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
                {"array", PropertyType::Object|PropertyType::Array, "array target"},
            }},
            {"link target", {
                {"value", PropertyType::Int},
            }, {
                {"origin", PropertyType::LinkingObjects|PropertyType::Array, "all types", "object"},
            }},
            {"array target", {
                {"value", PropertyType::Int},
            }},
        };

        InMemoryTestFile config;
        config.schema_mode = SchemaMode::Automatic;
        config.schema = schema;
        auto realm = Realm::get_shared_realm(config);

        CppContext ctx(realm);
        util::Any values = AnyDict{
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
        };
        realm->begin_transaction();
        Object::create(ctx, realm, *realm->schema().find("all types"), values, false);
        realm->commit_transaction();

        SECTION("read values from old realm") {
            Schema schema{
                {"all types", {
                    {"pk", PropertyType::Int, Property::IsPrimary{true}},
                }},
            };
            realm->update_schema(schema, 2, [](auto old_realm, auto new_realm, Schema&) {
                CppContext ctx(old_realm);
                Object obj = Object::get_for_primary_key(ctx, old_realm, "all types",
                                                         util::Any(INT64_C(1)));
                REQUIRE(obj.is_valid());

                REQUIRE(any_cast<bool>(obj.get_property_value<util::Any>(ctx, "bool")) == true);
                REQUIRE(any_cast<int64_t>(obj.get_property_value<util::Any>(ctx, "int")) == 5);
                REQUIRE(any_cast<float>(obj.get_property_value<util::Any>(ctx, "float")) == 2.2f);
                REQUIRE(any_cast<double>(obj.get_property_value<util::Any>(ctx, "double")) == 3.3);
                REQUIRE(any_cast<std::string>(obj.get_property_value<util::Any>(ctx, "string")) == "hello");
                REQUIRE(any_cast<std::string>(obj.get_property_value<util::Any>(ctx, "data")) == "olleh");
                REQUIRE(any_cast<Timestamp>(obj.get_property_value<util::Any>(ctx, "date")) == Timestamp(10, 20));

                auto link = any_cast<Object>(obj.get_property_value<util::Any>(ctx, "object"));
                REQUIRE(link.is_valid());
                REQUIRE(any_cast<int64_t>(link.get_property_value<util::Any>(ctx, "value")) == 10);

                auto list = any_cast<List>(obj.get_property_value<util::Any>(ctx, "array"));
                REQUIRE(list.size() == 1);

                CppContext list_ctx(ctx, *obj.get_object_schema().property_for_name("array"));
                link = any_cast<Object>(list.get(list_ctx, 0));
                REQUIRE(link.is_valid());
                REQUIRE(any_cast<int64_t>(link.get_property_value<util::Any>(list_ctx, "value")) == 20);

                CppContext ctx2(new_realm);
                obj = Object::get_for_primary_key(ctx, new_realm, "all types",
                                                  util::Any(INT64_C(1)));
                REQUIRE(obj.is_valid());
                REQUIRE_THROWS(obj.get_property_value<util::Any>(ctx, "bool"));
            });
        }

        SECTION("cannot mutate old realm") {
            realm->update_schema(schema, 2, [](auto old_realm, auto, Schema&) {
                CppContext ctx(old_realm);
                Object obj = Object::get_for_primary_key(ctx, old_realm, "all types",
                                                         util::Any(INT64_C(1)));
                REQUIRE(obj.is_valid());
                REQUIRE_THROWS(obj.set_property_value(ctx, "bool", util::Any(false), false));
                REQUIRE_THROWS(old_realm->begin_transaction());
            });
        }

        SECTION("cannot read values for removed properties from new realm") {
            Schema schema{
                {"all types", {
                    {"pk", PropertyType::Int, Property::IsPrimary{true}},
                }},
            };
            realm->update_schema(schema, 2, [](auto, auto new_realm, Schema&) {
                CppContext ctx(new_realm);
                Object obj = Object::get_for_primary_key(ctx, new_realm, "all types",
                                                         util::Any(INT64_C(1)));
                REQUIRE(obj.is_valid());
                REQUIRE_THROWS(obj.get_property_value<util::Any>(ctx, "bool"));
                REQUIRE_THROWS(obj.get_property_value<util::Any>(ctx, "object"));
                REQUIRE_THROWS(obj.get_property_value<util::Any>(ctx, "array"));
            });
        }

        SECTION("read values from new object") {
            realm->update_schema(schema, 2, [](auto, auto new_realm, Schema&) {
                CppContext ctx(new_realm);
                Object obj = Object::get_for_primary_key(ctx, new_realm, "all types",
                                                         util::Any(INT64_C(1)));
                REQUIRE(obj.is_valid());


                auto link = any_cast<Object>(obj.get_property_value<util::Any>(ctx, "object"));
                REQUIRE(link.is_valid());
                REQUIRE(any_cast<int64_t>(link.get_property_value<util::Any>(ctx, "value")) == 10);

                auto list = any_cast<List>(obj.get_property_value<util::Any>(ctx, "array"));
                REQUIRE(list.size() == 1);

                CppContext list_ctx(ctx, *obj.get_object_schema().property_for_name("array"));
                link = any_cast<Object>(list.get(list_ctx, 0));
                REQUIRE(link.is_valid());
                REQUIRE(any_cast<int64_t>(link.get_property_value<util::Any>(list_ctx, "value")) == 20);
            });
        }

        SECTION("read and write values in new object") {
            realm->update_schema(schema, 2, [](auto, auto new_realm, Schema&) {
                CppContext ctx(new_realm);
                Object obj = Object::get_for_primary_key(ctx, new_realm, "all types",
                                                         util::Any(INT64_C(1)));
                REQUIRE(obj.is_valid());

                REQUIRE(any_cast<bool>(obj.get_property_value<util::Any>(ctx, "bool")) == true);
                obj.set_property_value(ctx, "bool", util::Any(false), false);
                REQUIRE(any_cast<bool>(obj.get_property_value<util::Any>(ctx, "bool")) == false);

                REQUIRE(any_cast<int64_t>(obj.get_property_value<util::Any>(ctx, "int")) == 5);
                obj.set_property_value(ctx, "int", util::Any(INT64_C(6)), false);
                REQUIRE(any_cast<int64_t>(obj.get_property_value<util::Any>(ctx, "int")) == 6);

                REQUIRE(any_cast<float>(obj.get_property_value<util::Any>(ctx, "float")) == 2.2f);
                obj.set_property_value(ctx, "float", util::Any(1.23f), false);
                REQUIRE(any_cast<float>(obj.get_property_value<util::Any>(ctx, "float")) == 1.23f);

                REQUIRE(any_cast<double>(obj.get_property_value<util::Any>(ctx, "double")) == 3.3);
                obj.set_property_value(ctx, "double", util::Any(1.23), false);
                REQUIRE(any_cast<double>(obj.get_property_value<util::Any>(ctx, "double")) == 1.23);

                REQUIRE(any_cast<std::string>(obj.get_property_value<util::Any>(ctx, "string")) == "hello");
                obj.set_property_value(ctx, "string", util::Any("abc"s), false);
                REQUIRE(any_cast<std::string>(obj.get_property_value<util::Any>(ctx, "string")) == "abc");

                REQUIRE(any_cast<std::string>(obj.get_property_value<util::Any>(ctx, "data")) == "olleh");
                obj.set_property_value(ctx, "data", util::Any("abc"s), false);
                REQUIRE(any_cast<std::string>(obj.get_property_value<util::Any>(ctx, "data")) == "abc");

                REQUIRE(any_cast<Timestamp>(obj.get_property_value<util::Any>(ctx, "date")) == Timestamp(10, 20));
                obj.set_property_value(ctx, "date", util::Any(Timestamp(1, 2)), false);
                REQUIRE(any_cast<Timestamp>(obj.get_property_value<util::Any>(ctx, "date")) == Timestamp(1, 2));

                Object linked_obj(new_realm, "link target", 0);
                Object new_obj(new_realm, "link target", get_table(new_realm, "link target")->add_empty_row());

                auto linking = any_cast<Results>(linked_obj.get_property_value<util::Any>(ctx, "origin"));
                REQUIRE(linking.size() == 1);

                REQUIRE(any_cast<Object>(obj.get_property_value<util::Any>(ctx, "object")).row().get_index()
                        == linked_obj.row().get_index());
                obj.set_property_value(ctx, "object", util::Any(new_obj), false);
                REQUIRE(any_cast<Object>(obj.get_property_value<util::Any>(ctx, "object")).row().get_index()
                        == new_obj.row().get_index());

                REQUIRE(linking.size() == 0);
            });
        }

        SECTION("create object in new realm") {
            realm->update_schema(schema, 2, [&values](auto, auto new_realm, Schema&) {
                REQUIRE(new_realm->is_in_transaction());

                CppContext ctx(new_realm);
                any_cast<AnyDict&>(values)["pk"] = INT64_C(2);
                Object obj = Object::create(ctx, new_realm, "all types", values, false);

                REQUIRE(get_table(new_realm, "all types")->size() == 2);
                REQUIRE(get_table(new_realm, "link target")->size() == 2);
                REQUIRE(get_table(new_realm, "array target")->size() == 2);
                REQUIRE(any_cast<int64_t>(obj.get_property_value<util::Any>(ctx, "pk")) == 2);
            });
        }

        SECTION("upsert in new realm") {
            realm->update_schema(schema, 2, [&values](auto, auto new_realm, Schema&) {
                REQUIRE(new_realm->is_in_transaction());
                CppContext ctx(new_realm);
                any_cast<AnyDict&>(values)["bool"] = false;
                Object obj = Object::create(ctx, new_realm, "all types", values, true);
                REQUIRE(get_table(new_realm, "all types")->size() == 1);
                REQUIRE(get_table(new_realm, "link target")->size() == 2);
                REQUIRE(get_table(new_realm, "array target")->size() == 2);
                REQUIRE(any_cast<bool>(obj.get_property_value<util::Any>(ctx, "bool")) == false);
            });
        }

        SECTION("change primary key property type") {
            schema = set_type(schema, "all types", "pk", PropertyType::String);
            realm->update_schema(schema, 2, [](auto, auto new_realm, auto&) {
                Object obj(new_realm, "all types", 0);

                CppContext ctx(new_realm);
                obj.set_property_value(ctx, "pk", util::Any("1"s), false);
            });
        }

        SECTION("set primary key to duplicate values in migration") {
            auto bad_migration = [&](auto, auto new_realm, Schema&) {
                // shoud be able to create a new object with the same PK
                REQUIRE_NOTHROW(Object::create(ctx, new_realm, "all types", values, false));
                REQUIRE(get_table(new_realm, "all types")->size() == 2);

                // but it'll fail at the end
            };
            REQUIRE_THROWS_AS(realm->update_schema(schema, 2, bad_migration), DuplicatePrimaryKeyValueException);
            REQUIRE(get_table(realm, "all types")->size() == 1);

            auto good_migration = [&](auto, auto new_realm, Schema&) {
                REQUIRE_NOTHROW(Object::create(ctx, new_realm, "all types", values, false));

                // Change the old object's PK to elminate the duplication
                Object old_obj(new_realm, "all types", 0);
                CppContext ctx(new_realm);
                old_obj.set_property_value(ctx, "pk", util::Any(INT64_C(5)), false);
            };
            REQUIRE_NOTHROW(realm->update_schema(schema, 2, good_migration));
            REQUIRE(get_table(realm, "all types")->size() == 2);
        }
    }

    SECTION("property renaming") {
        InMemoryTestFile config;
        config.schema_mode = SchemaMode::Automatic;
        auto realm = Realm::get_shared_realm(config);

        struct Rename {
            StringData object_type;
            StringData old_name;
            StringData new_name;
        };

        auto apply_renames = [&](std::initializer_list<Rename> renames) -> Realm::MigrationFunction {
            return [=](SharedRealm, SharedRealm realm, Schema& schema) {
                for (auto rename : renames) {
                    ObjectStore::rename_property(realm->read_group(), schema,
                                                 rename.object_type, rename.old_name, rename.new_name);
                }
            };
        };

#define FAILED_RENAME(old_schema, new_schema, error, ...) do { \
    realm->update_schema(old_schema, 1); \
    REQUIRE_THROWS_WITH(realm->update_schema(new_schema, 2, apply_renames({__VA_ARGS__})), error); \
} while (false)

        Schema schema = {
            {"object", {
                {"value", PropertyType::Int},
            }},
        };

        SECTION("table does not exist in old schema") {
            auto schema2 = add_table(schema, {"object 2", {
                {"value 2", PropertyType::Int},
            }});
            FAILED_RENAME(schema, schema2,
                          "Cannot rename property 'object 2.value' because it does not exist.",
                          {"object 2", "value", "value 2"});
        }

        SECTION("table does not exist in new schema") {
            FAILED_RENAME(schema, {},
                          "Cannot rename properties for type 'object' because it has been removed from the Realm.",
                          {"object", "value", "value 2"});
        }

        SECTION("property does not exist in old schema") {
            auto schema2 = add_property(schema, "object", {"new", PropertyType::Int});
            FAILED_RENAME(schema, schema2,
                          "Cannot rename property 'object.nonexistent' because it does not exist.",
                          {"object", "nonexistent", "new"});
        }

        auto rename_value = [](Schema schema) {
            schema.find("object")->property_for_name("value")->name = "new";
            return schema;
        };

        SECTION("property does not exist in new schema") {
            FAILED_RENAME(schema, rename_value(schema),
                          "Renamed property 'object.nonexistent' does not exist.",
                          {"object", "value", "nonexistent"});
        }

        SECTION("source propety still exists in the new schema") {
            auto schema2 = add_property(schema, "object",
                                        {"new", PropertyType::Int});
            FAILED_RENAME(schema, schema2,
                          "Cannot rename property 'object.value' to 'new' because the source property still exists.",
                          {"object", "value", "new"});
        }

        SECTION("different type") {
            auto schema2 = rename_value(set_type(schema, "object", "value", PropertyType::Date));
            FAILED_RENAME(schema, schema2,
                          "Cannot rename property 'object.value' to 'new' because it would change from type 'int' to 'date'.",
                          {"object", "value", "new"});
        }

        SECTION("different link targets") {
            Schema schema = {
                {"target", {
                    {"value", PropertyType::Int},
                }},
                {"origin", {
                    {"link", PropertyType::Object|PropertyType::Nullable, "target"},
                }},
            };
            auto schema2 = set_target(schema, "origin", "link", "origin");
            schema2.find("origin")->property_for_name("link")->name = "new";
            FAILED_RENAME(schema, schema2,
                          "Cannot rename property 'origin.link' to 'new' because it would change from type '<target>' to '<origin>'.",
                          {"origin", "link", "new"});
        }

        SECTION("different linklist targets") {
            Schema schema = {
                {"target", {
                    {"value", PropertyType::Int},
                }},
                {"origin", {
                    {"link", PropertyType::Array|PropertyType::Object, "target"},
                }},
            };
            auto schema2 = set_target(schema, "origin", "link", "origin");
            schema2.find("origin")->property_for_name("link")->name = "new";
            FAILED_RENAME(schema, schema2,
                          "Cannot rename property 'origin.link' to 'new' because it would change from type 'array<target>' to 'array<origin>'.",
                          {"origin", "link", "new"});
        }

        SECTION("make required") {
            schema = set_optional(schema, "object", "value", true);
            auto schema2 = rename_value(set_optional(schema, "object", "value", false));
            FAILED_RENAME(schema, schema2,
                          "Cannot rename property 'object.value' to 'new' because it would change from optional to required.",
                          {"object", "value", "new"});
        }

        auto init = [&](Schema const& old_schema) {
            realm->update_schema(old_schema, 1);
            realm->begin_transaction();
            auto table = ObjectStore::table_for_object_type(realm->read_group(), "object");
            table->add_empty_row();
            table->set_int(0, 0, 10);
            realm->commit_transaction();
        };

#define SUCCESSFUL_RENAME(old_schema, new_schema, ...) do { \
    init(old_schema); \
    REQUIRE_NOTHROW(realm->update_schema(new_schema, 2, apply_renames({__VA_ARGS__}))); \
    REQUIRE(realm->schema() == new_schema); \
    VERIFY_SCHEMA(*realm); \
    REQUIRE(ObjectStore::table_for_object_type(realm->read_group(), "object")->get_int(0, 0) == 10); \
} while (false)

        SECTION("basic valid rename") {
            auto schema2 = rename_value(schema);
            SUCCESSFUL_RENAME(schema, schema2,
                              {"object", "value", "new"});
        }

        SECTION("chained rename") {
            auto schema2 = rename_value(schema);
            SUCCESSFUL_RENAME(schema, schema2,
                              {"object", "value", "a"},
                              {"object", "a", "b"},
                              {"object", "b", "new"});
        }

        SECTION("old is pk, new is not") {
            auto schema2 = rename_value(schema);
            schema = set_primary_key(schema, "object", "value");
            SUCCESSFUL_RENAME(schema, schema2, {"object", "value", "new"});
        }

        SECTION("new is pk, old is not") {
            auto schema2 = set_primary_key(rename_value(schema), "object", "new");
            SUCCESSFUL_RENAME(schema, schema2, {"object", "value", "new"});
        }

        SECTION("both are pk") {
            schema = set_primary_key(schema, "object", "value");
            auto schema2 = set_primary_key(rename_value(schema), "object", "new");
            SUCCESSFUL_RENAME(schema, schema2, {"object", "value", "new"});
        }

        SECTION("make optional") {
            auto schema2 = rename_value(set_optional(schema, "object", "value", true));
            SUCCESSFUL_RENAME(schema, schema2,
                              {"object", "value", "new"});
        }

        SECTION("add index") {
            auto schema2 = rename_value(set_indexed(schema, "object", "value", true));
            SUCCESSFUL_RENAME(schema, schema2, {"object", "value", "new"});
        }

        SECTION("remove index") {
            auto schema2 = rename_value(schema);
            schema = set_indexed(schema, "object", "value", true);
            SUCCESSFUL_RENAME(schema, schema2, {"object", "value", "new"});
        }
    }
}

TEST_CASE("migration: Immutable") {
    TestFile config;

    auto realm_with_schema = [&](Schema schema) {
        {
            auto realm = Realm::get_shared_realm(config);
            realm->update_schema(std::move(schema));
        }
        config.schema_mode = SchemaMode::Immutable;
        return Realm::get_shared_realm(config);
    };

    SECTION("allowed schema mismatches") {
        SECTION("index") {
            auto realm = realm_with_schema({
                {"object", {
                    {"indexed", PropertyType::Int, Property::IsPrimary{false}, Property::IsIndexed{true}},
                    {"unindexed", PropertyType::Int},
                }},
            });
            Schema schema = {
                {"object", {
                    {"indexed", PropertyType::Int},
                    {"unindexed", PropertyType::Int, Property::IsPrimary{false}, Property::IsIndexed{true}},
                }},
            };
            REQUIRE_NOTHROW(realm->update_schema(schema));
            REQUIRE(realm->schema() == schema);

            for (auto& object_schema : realm->schema()) {
                for (size_t i = 0; i < object_schema.persisted_properties.size(); ++i) {
                    REQUIRE(i == object_schema.persisted_properties[i].table_column);
                }
            }
        }

        SECTION("extra tables") {
            auto realm = realm_with_schema({
                {"object", {
                    {"value", PropertyType::Int},
                }},
                {"object 2", {
                    {"value", PropertyType::Int},
                }},
            });
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };
            REQUIRE_NOTHROW(realm->update_schema(schema));
        }

        SECTION("missing tables") {
            auto realm = realm_with_schema({
                {"object", {
                    {"value", PropertyType::Int},
                }},
            });
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
                {"second object", {
                    {"value", PropertyType::Int},
                }},
            };
            REQUIRE_NOTHROW(realm->update_schema(schema));
            REQUIRE(realm->schema() == schema);

            auto object_schema = realm->schema().find("object");
            REQUIRE(object_schema->persisted_properties.size() == 1);
            REQUIRE(object_schema->persisted_properties[0].table_column == 0);

            object_schema = realm->schema().find("second object");
            REQUIRE(object_schema->persisted_properties.size() == 1);
            REQUIRE(object_schema->persisted_properties[0].table_column == size_t(-1));
        }

        SECTION("extra columns in table") {
            auto realm = realm_with_schema({
                {"object", {
                    {"value", PropertyType::Int},
                    {"value 2", PropertyType::Int},
                }},
            });
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };
            REQUIRE_NOTHROW(realm->update_schema(schema));
        }
    }

    SECTION("disallowed mismatches") {
        SECTION("missing columns in table") {
            auto realm = realm_with_schema({
                {"object", {
                    {"value", PropertyType::Int},
                }},
            });
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                    {"value 2", PropertyType::Int},
                }},
            };
            REQUIRE_THROWS(realm->update_schema(schema));
        }

        SECTION("bump schema version") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };
            auto realm = realm_with_schema(schema);
            REQUIRE_THROWS(realm->update_schema(schema, 1));
        }
    }
}

TEST_CASE("migration: ReadOnly") {
    TestFile config;

    auto realm_with_schema = [&](Schema schema) {
        {
            auto realm = Realm::get_shared_realm(config);
            realm->update_schema(std::move(schema));
        }
        config.schema_mode = SchemaMode::ReadOnlyAlternative;
        return Realm::get_shared_realm(config);
    };

    SECTION("allowed schema mismatches") {
        SECTION("index") {
            auto realm = realm_with_schema({
                {"object", {
                    {"indexed", PropertyType::Int, Property::IsPrimary{false}, Property::IsIndexed{true}},
                    {"unindexed", PropertyType::Int},
                }},
            });
            Schema schema = {
                {"object", {
                    {"indexed", PropertyType::Int},
                    {"unindexed", PropertyType::Int, Property::IsPrimary{false}, Property::IsIndexed{true}},
                }},
            };
            REQUIRE_NOTHROW(realm->update_schema(schema));
            REQUIRE(realm->schema() == schema);

            for (auto& object_schema : realm->schema()) {
                for (size_t i = 0; i < object_schema.persisted_properties.size(); ++i) {
                    REQUIRE(i == object_schema.persisted_properties[i].table_column);
                }
            }
        }

        SECTION("extra tables") {
            auto realm = realm_with_schema({
                {"object", {
                    {"value", PropertyType::Int},
                }},
                {"object 2", {
                    {"value", PropertyType::Int},
                }},
            });
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };
            REQUIRE_NOTHROW(realm->update_schema(schema));
        }

        SECTION("extra columns in table") {
            auto realm = realm_with_schema({
                {"object", {
                    {"value", PropertyType::Int},
                    {"value 2", PropertyType::Int},
                }},
            });
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };
            REQUIRE_NOTHROW(realm->update_schema(schema));
        }

        SECTION("missing tables") {
            auto realm = realm_with_schema({
                {"object", {
                    {"value", PropertyType::Int},
                }},
            });
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
                {"second object", {
                    {"value", PropertyType::Int},
                }},
            };
            REQUIRE_NOTHROW(realm->update_schema(schema));
        }

        SECTION("bump schema version") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }},
            };
            auto realm = realm_with_schema(schema);
            REQUIRE_NOTHROW(realm->update_schema(schema, 1));
        }
    }

    SECTION("disallowed mismatches") {

        SECTION("missing columns in table") {
            auto realm = realm_with_schema({
                {"object", {
                    {"value", PropertyType::Int},
                }},
            });
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                    {"value 2", PropertyType::Int},
                }},
            };
            REQUIRE_THROWS(realm->update_schema(schema));
        }
    }
}

TEST_CASE("migration: ResetFile") {
    TestFile config;
    config.schema_mode = SchemaMode::ResetFile;

    Schema schema = {
        {"object", {
            {"value", PropertyType::Int},
        }},
        {"object 2", {
            {"value", PropertyType::Int},
        }},
    };

// To verify that the file has actually be deleted and recreated, on
// non-Windows we need to hold an open file handle to the old file to force
// using a new inode, but on Windows we *can't*
#ifdef _WIN32
    auto get_fileid = [&] {
        // this is wrong for non-ascii but it's what core does
        std::wstring ws(config.path.begin(), config.path.end());
        HANDLE handle = CreateFile2(ws.c_str(), GENERIC_READ,
                                    FILE_SHARE_READ | FILE_SHARE_WRITE, OPEN_EXISTING,
                                    nullptr);
        REQUIRE(handle != INVALID_HANDLE_VALUE);
        auto close = util::make_scope_exit([=]() noexcept { CloseHandle(handle); });

        BY_HANDLE_FILE_INFORMATION info{};
        REQUIRE(GetFileInformationByHandle(handle, &info));
        return (DWORDLONG)info.nFileIndexHigh + (DWORDLONG)info.nFileIndexLow;
    };
#else
    auto get_fileid = [&] {
        util::File::UniqueID id;
        util::File::get_unique_id(config.path, id);
        return id.inode;
    };
    File holder(config.path, File::mode_Write);
#endif

    {
        auto realm = Realm::get_shared_realm(config);
        auto ino = get_fileid();
        realm->update_schema(schema);
        REQUIRE(ino == get_fileid());
        realm->begin_transaction();
        ObjectStore::table_for_object_type(realm->read_group(), "object")->add_empty_row();
        realm->commit_transaction();
    }
    auto realm = Realm::get_shared_realm(config);
    auto ino = get_fileid();

    SECTION("file is reset when schema version increases") {
        realm->update_schema(schema, 1);
        REQUIRE(ObjectStore::table_for_object_type(realm->read_group(), "object")->size() == 0);
        REQUIRE(ino != get_fileid());
    }

    SECTION("file is reset when an existing table is modified") {
        realm->update_schema(add_property(schema, "object",
                                          {"value 2", PropertyType::Int}));
        REQUIRE(ObjectStore::table_for_object_type(realm->read_group(), "object")->size() == 0);
        REQUIRE(ino != get_fileid());
    }

    SECTION("file is not reset when adding a new table") {
        realm->update_schema(add_table(schema, {"object 3", {
            {"value", PropertyType::Int},
        }}));
        REQUIRE(ObjectStore::table_for_object_type(realm->read_group(), "object")->size() == 1);
        REQUIRE(realm->schema().size() == 3);
        REQUIRE(ino == get_fileid());
    }

    SECTION("file is not reset when removing a table") {
        realm->update_schema(remove_table(schema, "object 2"));
        REQUIRE(ObjectStore::table_for_object_type(realm->read_group(), "object")->size() == 1);
        REQUIRE(ObjectStore::table_for_object_type(realm->read_group(), "object 2"));
        REQUIRE(realm->schema().size() == 1);
        REQUIRE(ino == get_fileid());
    }

    SECTION("file is not reset when adding an index") {
        realm->update_schema(set_indexed(schema, "object", "value", true));
        REQUIRE(ObjectStore::table_for_object_type(realm->read_group(), "object")->size() == 1);
        REQUIRE(ino == get_fileid());
    }

    SECTION("file is not reset when removing an index") {
        realm->update_schema(set_indexed(schema, "object", "value", true));
        realm->update_schema(schema);
        REQUIRE(ObjectStore::table_for_object_type(realm->read_group(), "object")->size() == 1);
        REQUIRE(ino == get_fileid());
    }
}

TEST_CASE("migration: Additive") {
    Schema schema = {
        {"object", {
            {"value", PropertyType::Int, Property::IsPrimary{false}, Property::IsIndexed{true}},
            {"value 2", PropertyType::Int|PropertyType::Nullable},
        }},
    };

    TestFile config;
    config.schema_mode = SchemaMode::Additive;
    config.cache = false;
    config.schema = schema;
    auto realm = Realm::get_shared_realm(config);
    realm->update_schema(schema);

    SECTION("can add new properties to existing tables") {
        REQUIRE_NOTHROW(realm->update_schema(add_property(schema, "object",
                                                          {"value 3", PropertyType::Int})));
        REQUIRE(ObjectStore::table_for_object_type(realm->read_group(), "object")->get_column_count() == 3);
    }

    SECTION("can add new tables") {
        REQUIRE_NOTHROW(realm->update_schema(add_table(schema, {"object 2", {
            {"value", PropertyType::Int},
        }})));
        REQUIRE(ObjectStore::table_for_object_type(realm->read_group(), "object"));
        REQUIRE(ObjectStore::table_for_object_type(realm->read_group(), "object 2"));
    }

    SECTION("indexes are updated when schema version is bumped") {
        auto table = ObjectStore::table_for_object_type(realm->read_group(), "object");
        REQUIRE(table->has_search_index(0));
        REQUIRE(!table->has_search_index(1));

        REQUIRE_NOTHROW(realm->update_schema(set_indexed(schema, "object", "value", false), 1));
        REQUIRE(!table->has_search_index(0));

        REQUIRE_NOTHROW(realm->update_schema(set_indexed(schema, "object", "value 2", true), 2));
        REQUIRE(table->has_search_index(1));
    }

    SECTION("indexes are not updated when schema version is not bumped") {
        auto table = ObjectStore::table_for_object_type(realm->read_group(), "object");
        REQUIRE(table->has_search_index(0));
        REQUIRE(!table->has_search_index(1));

        REQUIRE_NOTHROW(realm->update_schema(set_indexed(schema, "object", "value", false)));
        REQUIRE(table->has_search_index(0));

        REQUIRE_NOTHROW(realm->update_schema(set_indexed(schema, "object", "value 2", true)));
        REQUIRE(!table->has_search_index(1));
    }

    SECTION("can remove properties from existing tables, but column is not removed") {
        auto table = ObjectStore::table_for_object_type(realm->read_group(), "object");
        REQUIRE_NOTHROW(realm->update_schema(remove_property(schema, "object", "value")));
        REQUIRE(ObjectStore::table_for_object_type(realm->read_group(), "object")->get_column_count() == 2);
        auto const& properties = realm->schema().find("object")->persisted_properties;
        REQUIRE(properties.size() == 1);
        REQUIRE(properties[0].table_column == 1);
    }

    SECTION("cannot change existing property types") {
        REQUIRE_THROWS(realm->update_schema(set_type(schema, "object", "value", PropertyType::Float)));
    }

    SECTION("cannot change existing property nullability") {
        REQUIRE_THROWS(realm->update_schema(set_optional(schema, "object", "value", true)));
        REQUIRE_THROWS(realm->update_schema(set_optional(schema, "object", "value 2", false)));
    }

    SECTION("cannot change existing link targets") {
        REQUIRE_NOTHROW(realm->update_schema(add_table(schema, {"object 2", {
            {"link", PropertyType::Object|PropertyType::Nullable, "object"},
        }})));
        REQUIRE_THROWS(realm->update_schema(set_target(realm->schema(), "object 2", "link", "object 2")));
    }

    SECTION("cannot change primary keys") {
        REQUIRE_THROWS(realm->update_schema(set_primary_key(schema, "object", "value")));

        REQUIRE_NOTHROW(realm->update_schema(add_table(schema, {"object 2", {
            {"pk", PropertyType::Int, Property::IsPrimary{true}},
        }})));

        REQUIRE_THROWS(realm->update_schema(set_primary_key(realm->schema(), "object 2", "")));
    }

    SECTION("schema version is allowed to go down") {
        REQUIRE_NOTHROW(realm->update_schema(schema, 1));
        REQUIRE(realm->schema_version() == 1);
        REQUIRE_NOTHROW(realm->update_schema(schema, 0));
        REQUIRE(realm->schema_version() == 1);
    }

    SECTION("migration function is not used") {
        REQUIRE_NOTHROW(realm->update_schema(schema, 1,
                                             [&](SharedRealm, SharedRealm, Schema&) { REQUIRE(false); }));
    }

    SECTION("add new columns at end from different SG") {
        auto realm2 = Realm::get_shared_realm(config);
        auto& group = realm2->read_group();
        realm2->begin_transaction();
        auto table = ObjectStore::table_for_object_type(group, "object");
        table->add_column(type_Int, "new column");
        realm2->commit_transaction();

        REQUIRE_NOTHROW(realm->refresh());
        REQUIRE(realm->schema() == schema);
        REQUIRE(realm->schema().find("object")->persisted_properties[0].table_column == 0);
        REQUIRE(realm->schema().find("object")->persisted_properties[1].table_column == 1);
    }

    SECTION("add new columns at beginning from different SG") {
        auto realm2 = Realm::get_shared_realm(config);
        auto& group = realm2->read_group();
        realm2->begin_transaction();
        auto table = ObjectStore::table_for_object_type(group, "object");
        table->insert_column(0, type_Int, "new column");
        realm2->commit_transaction();

        REQUIRE_NOTHROW(realm->refresh());
        REQUIRE(realm->schema() == schema);
        REQUIRE(realm->schema().find("object")->persisted_properties[0].table_column == 1);
        REQUIRE(realm->schema().find("object")->persisted_properties[1].table_column == 2);
    }

    SECTION("opening new Realms uses the correct schema after an external change") {
        auto realm2 = Realm::get_shared_realm(config);
        auto& group = realm2->read_group();
        realm2->begin_transaction();
        auto table = ObjectStore::table_for_object_type(group, "object");
        table->insert_column(0, type_Double, "newcol");
        realm2->commit_transaction();

        REQUIRE_NOTHROW(realm->refresh());
        REQUIRE(realm->schema() == schema);
        REQUIRE(realm->schema().find("object")->persisted_properties[0].table_column == 1);
        REQUIRE(realm->schema().find("object")->persisted_properties[1].table_column == 2);

        // Gets the schema from the RealmCoordinator
        auto realm3 = Realm::get_shared_realm(config);
        REQUIRE(realm3->schema().find("object")->persisted_properties[0].table_column == 1);
        REQUIRE(realm3->schema().find("object")->persisted_properties[1].table_column == 2);

        // Close and re-open the file entirely so that the coordinator is recreated
        realm.reset();
        realm2.reset();
        realm3.reset();

        realm = Realm::get_shared_realm(config);
        REQUIRE(realm->schema() == schema);
        REQUIRE(realm->schema().find("object")->persisted_properties[0].table_column == 1);
        REQUIRE(realm->schema().find("object")->persisted_properties[1].table_column == 2);
    }

    SECTION("can have different subsets of columns in different Realm instances") {
        auto config2 = config;
        config2.schema = add_property(schema, "object",
                                      {"value 3", PropertyType::Int});
        auto config3 = config;
        config3.schema = remove_property(schema, "object", "value 2");

        auto config4 = config;
        config4.schema = util::none;

        auto realm2 = Realm::get_shared_realm(config2);
        auto realm3 = Realm::get_shared_realm(config3);
        REQUIRE(realm->schema().find("object")->persisted_properties.size() == 2);
        REQUIRE(realm2->schema().find("object")->persisted_properties.size() == 3);
        REQUIRE(realm3->schema().find("object")->persisted_properties.size() == 1);

        realm->refresh();
        realm2->refresh();
        REQUIRE(realm->schema().find("object")->persisted_properties.size() == 2);
        REQUIRE(realm2->schema().find("object")->persisted_properties.size() == 3);

        // No schema specified; should see all of them
        auto realm4 = Realm::get_shared_realm(config4);
        REQUIRE(realm4->schema().find("object")->persisted_properties.size() == 3);
    }

    SECTION("updating a schema to include already-present column") {
        auto config2 = config;
        config2.schema = add_property(schema, "object",
                                      {"value 3", PropertyType::Int});
        auto realm2 = Realm::get_shared_realm(config2);

        REQUIRE_NOTHROW(realm->update_schema(*config2.schema));
        REQUIRE(realm->schema().find("object")->persisted_properties.size() == 3);
        auto& properties = realm->schema().find("object")->persisted_properties;
        REQUIRE(properties[0].table_column == 0);
        REQUIRE(properties[1].table_column == 1);
        REQUIRE(properties[2].table_column == 2);
    }

    SECTION("increasing schema version without modifying schema properly leaves the schema untouched") {
        TestFile config1;
        config1.schema = schema;
        config1.schema_mode = SchemaMode::Additive;
        config1.schema_version = 0;

        auto realm1 = Realm::get_shared_realm(config1);
        REQUIRE(realm1->schema().size() == 1);
        Schema schema1 = realm1->schema();
        realm1->close();

        auto config2 = config1;
        config2.schema_version = 1;
        auto realm2 = Realm::get_shared_realm(config2);
        REQUIRE(realm2->schema() == schema1);
    }

    SECTION("invalid schema update leaves the schema untouched") {
        auto config2 = config;
        config2.schema = add_property(schema, "object", {"value 3", PropertyType::Int});
        auto realm2 = Realm::get_shared_realm(config2);

        REQUIRE_THROWS(realm->update_schema(add_property(schema, "object", {"value 3", PropertyType::Float})));
        REQUIRE(realm->schema().find("object")->persisted_properties.size() == 2);
    }

    SECTION("update_schema() does not begin a write transaction when extra columns are present") {
        realm->begin_transaction();

        auto realm2 = Realm::get_shared_realm(config);
        // will deadlock if it tries to start a write transaction
        realm2->update_schema(remove_property(schema, "object", "value"));
    }

    SECTION("update_schema() does not begin a write transaction when indexes are changed without bumping schema version") {
        realm->begin_transaction();

        auto realm2 = Realm::get_shared_realm(config);
        // will deadlock if it tries to start a write transaction
        realm->update_schema(set_indexed(schema, "object", "value 2", true));
    }

    SECTION("update_schema() does not begin a write transaction for invalid schema changes") {
        realm->begin_transaction();

        auto realm2 = Realm::get_shared_realm(config);
        auto new_schema = add_property(remove_property(schema, "object", "value"),
                                       "object", {"value", PropertyType::Float});
        // will deadlock if it tries to start a write transaction
        REQUIRE_THROWS(realm2->update_schema(new_schema));
    }
}

TEST_CASE("migration: Manual") {
    TestFile config;
    config.schema_mode = SchemaMode::Manual;
    auto realm = Realm::get_shared_realm(config);

    Schema schema = {
        {"object", {
            {"pk", PropertyType::Int, Property::IsPrimary{true}},
            {"value", PropertyType::Int, Property::IsPrimary{false}, Property::IsIndexed{true}},
            {"optional", PropertyType::Int|PropertyType::Nullable},
        }},
        {"link origin", {
            {"not a pk", PropertyType::Int},
            {"object", PropertyType::Object|PropertyType::Nullable, "object"},
            {"array", PropertyType::Array|PropertyType::Object, "object"},
        }}
    };
    realm->update_schema(schema);

#define REQUIRE_MIGRATION(schema, migration) do { \
    Schema new_schema = (schema); \
    REQUIRE_THROWS(realm->update_schema(new_schema)); \
    REQUIRE(realm->schema_version() == 0); \
    REQUIRE_THROWS(realm->update_schema(new_schema, 1, [](SharedRealm, SharedRealm, Schema&){})); \
    REQUIRE(realm->schema_version() == 0); \
    REQUIRE_NOTHROW(realm->update_schema(new_schema, 1, migration)); \
    REQUIRE(realm->schema_version() == 1); \
} while (false)

    SECTION("add new table") {
        REQUIRE_MIGRATION(add_table(schema, {"new table", {
            {"value", PropertyType::Int},
        }}), [](SharedRealm, SharedRealm realm, Schema&) {
            realm->read_group().add_table("class_new table")->add_column(type_Int, "value");
        });
    }
    SECTION("add property to table") {
        REQUIRE_MIGRATION(add_property(schema, "object", {"new", PropertyType::Int}),
                          [](SharedRealm, SharedRealm realm, Schema&) {
                              get_table(realm, "object")->add_column(type_Int, "new");
                          });
    }
    SECTION("remove property from table") {
        REQUIRE_MIGRATION(remove_property(schema, "object", "value"),
                          [](SharedRealm, SharedRealm realm, Schema&) {
                              get_table(realm, "object")->remove_column(1);
                          });
    }
    SECTION("add primary key to table") {
        REQUIRE_MIGRATION(set_primary_key(schema, "link origin", "not a pk"),
                          [](SharedRealm, SharedRealm realm, Schema&) {
                              ObjectStore::set_primary_key_for_object(realm->read_group(), "link origin", "not a pk");
                              get_table(realm, "link origin")->add_search_index(0);
                          });
    }
    SECTION("remove primary key from table") {
        REQUIRE_MIGRATION(set_primary_key(schema, "object", ""),
                          [](SharedRealm, SharedRealm realm, Schema&) {
                              ObjectStore::set_primary_key_for_object(realm->read_group(), "object", "");
                              get_table(realm, "object")->remove_search_index(0);
                          });
    }
    SECTION("change primary key") {
        REQUIRE_MIGRATION(set_primary_key(schema, "object", "value"),
                          [](SharedRealm, SharedRealm realm, Schema&) {
                              ObjectStore::set_primary_key_for_object(realm->read_group(), "object", "value");
                              auto table = get_table(realm, "object");
                              table->remove_search_index(0);
                              table->add_search_index(1);
                          });
    }
    SECTION("change property type") {
        REQUIRE_MIGRATION(set_type(schema, "object", "value", PropertyType::Date),
                          [](SharedRealm, SharedRealm realm, Schema&) {
                              auto table = get_table(realm, "object");
                              table->remove_column(1);
                              size_t col = table->add_column(type_Timestamp, "value");
                              table->add_search_index(col);
                          });
    }
    SECTION("change link target") {
        REQUIRE_MIGRATION(set_target(schema, "link origin", "object", "link origin"),
                          [](SharedRealm, SharedRealm realm, Schema&) {
                              auto table = get_table(realm, "link origin");
                              table->remove_column(1);
                              table->add_column_link(type_Link, "object", *table);
                          });
    }
    SECTION("change linklist target") {
        REQUIRE_MIGRATION(set_target(schema, "link origin", "array", "link origin"),
                          [](SharedRealm, SharedRealm realm, Schema&) {
                              auto table = get_table(realm, "link origin");
                              table->remove_column(2);
                              table->add_column_link(type_LinkList, "array", *table);
                          });
    }
    SECTION("make property optional") {
        REQUIRE_MIGRATION(set_optional(schema, "object", "value", true),
                          [](SharedRealm, SharedRealm realm, Schema&) {
                              auto table = get_table(realm, "object");
                              table->remove_column(1);
                              size_t col = table->add_column(type_Int, "value", true);
                              table->add_search_index(col);
                          });
    }
    SECTION("make property required") {
        REQUIRE_MIGRATION(set_optional(schema, "object", "optional", false),
                          [](SharedRealm, SharedRealm realm, Schema&) {
                              auto table = get_table(realm, "object");
                              table->remove_column(2);
                              table->add_column(type_Int, "optional", false);
                          });
    }
    SECTION("add index") {
        REQUIRE_MIGRATION(set_indexed(schema, "object", "optional", true),
                          [](SharedRealm, SharedRealm realm, Schema&) {
                              get_table(realm, "object")->add_search_index(2);
                          });
    }
    SECTION("remove index") {
        REQUIRE_MIGRATION(set_indexed(schema, "object", "value", false),
                          [](SharedRealm, SharedRealm realm, Schema&) {
                              get_table(realm, "object")->remove_search_index(1);
                          });
    }
    SECTION("reorder properties") {
        auto schema2 = schema;
        auto& properties = schema2.find("object")->persisted_properties;
        std::swap(properties[0], properties[1]);
        REQUIRE_NOTHROW(realm->update_schema(schema2));
    }

    SECTION("cannot lower schema version") {
        REQUIRE_NOTHROW(realm->update_schema(schema, 1, [](SharedRealm, SharedRealm, Schema&){}));
        REQUIRE(realm->schema_version() == 1);
        REQUIRE_THROWS(realm->update_schema(schema, 0, [](SharedRealm, SharedRealm, Schema&){}));
        REQUIRE(realm->schema_version() == 1);
    }

    SECTION("update_schema() does not begin a write transaction when schema version is unchanged") {
        realm->begin_transaction();

        auto realm2 = Realm::get_shared_realm(config);
        // will deadlock if it tries to start a write transaction
        REQUIRE_NOTHROW(realm2->update_schema(schema));
        REQUIRE_THROWS(realm2->update_schema(remove_property(schema, "object", "value")));
    }

    SECTION("null migration callback should throw SchemaMismatchException") {
        Schema new_schema = remove_property(schema, "object", "value");
        REQUIRE_THROWS_AS(realm->update_schema(new_schema, 1, nullptr), SchemaMismatchException);
    }
}
