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

#include "util/event_loop.hpp"
#include "util/test_file.hpp"
#include "util/templated_test_case.hpp"

#include "binding_context.hpp"
#include "object_schema.hpp"
#include "object_store.hpp"
#include "property.hpp"
#include "results.hpp"
#include "schema.hpp"

#include "impl/realm_coordinator.hpp"

#include <realm/group.hpp>

namespace realm {
class TestHelper {
public:
    static SharedGroup& get_shared_group(SharedRealm const& shared_realm)
    {
        return *Realm::Internal::get_shared_group(*shared_realm);
    }

    static void begin_read(SharedRealm const& shared_realm, VersionID version)
    {
        Realm::Internal::begin_read(*shared_realm, version);
    }
};
}

using namespace realm;

TEST_CASE("SharedRealm: get_shared_realm()") {
    TestFile config;
    config.schema_version = 1;
    config.schema = Schema{
        {"object", {
            {"value", PropertyType::Int}
        }},
    };

    SECTION("should return the same instance when caching is enabled") {
        auto realm1 = Realm::get_shared_realm(config);
        auto realm2 = Realm::get_shared_realm(config);
        REQUIRE(realm1.get() == realm2.get());
    }

    SECTION("should return different instances when caching is disabled") {
        config.cache = false;
        auto realm1 = Realm::get_shared_realm(config);
        auto realm2 = Realm::get_shared_realm(config);
        REQUIRE(realm1.get() != realm2.get());
    }

    SECTION("should validate that the config is sensible") {
        SECTION("bad encryption key") {
            config.encryption_key = std::vector<char>(2, 0);
            REQUIRE_THROWS(Realm::get_shared_realm(config));
        }

        SECTION("schema without schema version") {
            config.schema_version = ObjectStore::NotVersioned;
            REQUIRE_THROWS(Realm::get_shared_realm(config));
        }

        SECTION("migration function for immutable") {
            config.schema_mode = SchemaMode::Immutable;
            config.migration_function = [](auto, auto, auto) { };
            REQUIRE_THROWS(Realm::get_shared_realm(config));
        }

        SECTION("migration function for read-only") {
            config.schema_mode = SchemaMode::ReadOnlyAlternative;
            config.migration_function = [](auto, auto, auto) { };
            REQUIRE_THROWS(Realm::get_shared_realm(config));
        }

        SECTION("migration function for additive-only") {
            config.schema_mode = SchemaMode::Additive;
            config.migration_function = [](auto, auto, auto) { };
            REQUIRE_THROWS(Realm::get_shared_realm(config));
        }

        SECTION("initialization function for immutable") {
            config.schema_mode = SchemaMode::Immutable;
            config.initialization_function = [](auto) { };
            REQUIRE_THROWS(Realm::get_shared_realm(config));
        }

        SECTION("initialization function for read-only") {
            config.schema_mode = SchemaMode::ReadOnlyAlternative;
            config.initialization_function = [](auto) { };
            REQUIRE_THROWS(Realm::get_shared_realm(config));
        }
    }

    SECTION("should reject mismatched config") {
        SECTION("cached") { }
        SECTION("uncached") { config.cache = false; }

        SECTION("schema version") {
            auto realm = Realm::get_shared_realm(config);
            config.schema_version = 2;
            REQUIRE_THROWS(Realm::get_shared_realm(config));

            config.schema = util::none;
            config.schema_version = ObjectStore::NotVersioned;
            REQUIRE_NOTHROW(Realm::get_shared_realm(config));
        }

        SECTION("schema mode") {
            auto realm = Realm::get_shared_realm(config);
            config.schema_mode = SchemaMode::Manual;
            REQUIRE_THROWS(Realm::get_shared_realm(config));
        }

        SECTION("durability") {
            auto realm = Realm::get_shared_realm(config);
            config.in_memory = true;
            REQUIRE_THROWS(Realm::get_shared_realm(config));
        }

        SECTION("schema") {
            auto realm = Realm::get_shared_realm(config);
            config.schema = Schema{
                {"object", {
                    {"value", PropertyType::Int},
                    {"value2", PropertyType::Int}
                }},
            };
            REQUIRE_THROWS(Realm::get_shared_realm(config));
        }
    }

    SECTION("should verify that the schema is valid") {
        config.schema = Schema{
            {"object",
                {{"value", PropertyType::Int}},
                {{"invalid backlink", PropertyType::LinkingObjects|PropertyType::Array, "object", "value"}}
            }
        };
        REQUIRE_THROWS_WITH(Realm::get_shared_realm(config),
                            Catch::Matchers::Contains("origin of linking objects property"));
    }

    SECTION("should apply the schema if one is supplied") {
        Realm::get_shared_realm(config);

        {
            Group g(config.path);
            auto table = ObjectStore::table_for_object_type(g, "object");
            REQUIRE(table);
            REQUIRE(table->get_column_count() == 1);
            REQUIRE(table->get_column_name(0) == "value");
        }

        config.schema_version = 2;
        config.schema = Schema{
            {"object", {
                {"value", PropertyType::Int},
                {"value2", PropertyType::Int}
            }},
        };
        bool migration_called = false;
        config.migration_function = [&](SharedRealm old_realm, SharedRealm new_realm, Schema&) {
            migration_called = true;
            REQUIRE(ObjectStore::table_for_object_type(old_realm->read_group(), "object")->get_column_count() == 1);
            REQUIRE(ObjectStore::table_for_object_type(new_realm->read_group(), "object")->get_column_count() == 2);
        };
        Realm::get_shared_realm(config);
        REQUIRE(migration_called);
    }

    SECTION("should properly roll back from migration errors") {
        Realm::get_shared_realm(config);

        config.schema_version = 2;
        config.schema = Schema{
            {"object", {
                {"value", PropertyType::Int},
                {"value2", PropertyType::Int}
            }},
        };
        bool migration_called = false;
        config.migration_function = [&](SharedRealm old_realm, SharedRealm new_realm, Schema&) {
            REQUIRE(ObjectStore::table_for_object_type(old_realm->read_group(), "object")->get_column_count() == 1);
            REQUIRE(ObjectStore::table_for_object_type(new_realm->read_group(), "object")->get_column_count() == 2);
            if (!migration_called) {
                migration_called = true;
                throw "error";
            }
        };
        REQUIRE_THROWS_WITH(Realm::get_shared_realm(config), "error");
        REQUIRE(migration_called);
        REQUIRE_NOTHROW(Realm::get_shared_realm(config));
    }

    SECTION("should read the schema from the file if none is supplied") {
        Realm::get_shared_realm(config);

        config.schema = util::none;
        auto realm = Realm::get_shared_realm(config);
        REQUIRE(realm->schema().size() == 1);
        auto it = realm->schema().find("object");
        REQUIRE(it != realm->schema().end());
        REQUIRE(it->persisted_properties.size() == 1);
        REQUIRE(it->persisted_properties[0].name == "value");
        REQUIRE(it->persisted_properties[0].table_column == 0);
    }

    SECTION("should read the proper schema from the file if a custom version is supplied") {
        Realm::get_shared_realm(config);

        config.schema = util::none;
        config.cache = false;
        config.schema_mode = SchemaMode::Additive;
        config.schema_version = 0;

        auto realm = Realm::get_shared_realm(config);
        REQUIRE(realm->schema().size() == 1);

        auto& shared_group = TestHelper::get_shared_group(realm);
        shared_group.begin_read();
        shared_group.pin_version();
        VersionID old_version = shared_group.get_version_of_current_transaction();
        realm->close();

        config.schema = Schema{
            {"object", {
                {"value", PropertyType::Int}
            }},
            {"object1", {
                {"value", PropertyType::Int}
            }},
        };
        config.schema_version = 1;
        realm = Realm::get_shared_realm(config);
        REQUIRE(realm->schema().size() == 2);

        config.schema = util::none;
        auto old_realm = Realm::get_shared_realm(config);
        TestHelper::begin_read(old_realm, old_version);
        REQUIRE(old_realm->schema().size() == 1);
    }

    SECTION("should sensibly handle opening an uninitialized file without a schema specified") {
        SECTION("cached") { }
        SECTION("uncached") { config.cache = false; }

        // create an empty file
        File(config.path, File::mode_Write);

        // open the empty file, but don't initialize the schema
        Realm::Config config_without_schema = config;
        config_without_schema.schema = util::none;
        config_without_schema.schema_version = ObjectStore::NotVersioned;
        auto realm = Realm::get_shared_realm(config_without_schema);
        REQUIRE(realm->schema().empty());
        REQUIRE(realm->schema_version() == ObjectStore::NotVersioned);
        // verify that we can get another Realm instance
        REQUIRE_NOTHROW(Realm::get_shared_realm(config_without_schema));

        // verify that we can also still open the file with a proper schema
        auto realm2 = Realm::get_shared_realm(config);
        REQUIRE_FALSE(realm2->schema().empty());
        REQUIRE(realm2->schema_version() == 1);
    }

    SECTION("should populate the table columns in the schema when opening as immutable") {
        Realm::get_shared_realm(config);

        config.schema_mode = SchemaMode::Immutable;
        auto realm = Realm::get_shared_realm(config);
        auto it = realm->schema().find("object");
        REQUIRE(it != realm->schema().end());
        REQUIRE(it->persisted_properties.size() == 1);
        REQUIRE(it->persisted_properties[0].name == "value");
        REQUIRE(it->persisted_properties[0].table_column == 0);
    }

    SECTION("should support using different table subsets on different threads") {
        config.cache = false;
        auto realm1 = Realm::get_shared_realm(config);

        config.schema = Schema{
            {"object 2", {
                {"value", PropertyType::Int}
            }},
        };
        auto realm2 = Realm::get_shared_realm(config);

        config.schema = util::none;
        auto realm3 = Realm::get_shared_realm(config);

        config.schema = Schema{
            {"object", {
                {"value", PropertyType::Int}
            }},
        };
        auto realm4 = Realm::get_shared_realm(config);

        realm1->refresh();
        realm2->refresh();

        REQUIRE(realm1->schema().size() == 1);
        REQUIRE(realm1->schema().find("object") != realm1->schema().end());
        REQUIRE(realm2->schema().size() == 1);
        REQUIRE(realm2->schema().find("object 2") != realm2->schema().end());
        REQUIRE(realm3->schema().size() == 2);
        REQUIRE(realm3->schema().find("object") != realm3->schema().end());
        REQUIRE(realm3->schema().find("object 2") != realm3->schema().end());
        REQUIRE(realm4->schema().size() == 1);
        REQUIRE(realm4->schema().find("object") != realm4->schema().end());
    }

// The ExternalCommitHelper implementation on Windows doesn't rely on files
#ifndef _WIN32
    SECTION("should throw when creating the notification pipe fails") {
        util::try_make_dir(config.path + ".note");
        REQUIRE_THROWS(Realm::get_shared_realm(config));
        util::remove_dir(config.path + ".note");
    }
#endif

    SECTION("should get different instances on different threads") {
        auto realm1 = Realm::get_shared_realm(config);
        std::thread([&]{
            auto realm2 = Realm::get_shared_realm(config);
            REQUIRE(realm1 != realm2);
        }).join();
    }

    SECTION("should detect use of Realm on incorrect thread") {
        auto realm = Realm::get_shared_realm(config);
        std::thread([&]{
            REQUIRE_THROWS_AS(realm->verify_thread(), IncorrectThreadException);
        }).join();
    }

    SECTION("should get different instances for different explicit execuction contexts") {
        config.execution_context = 0;
        auto realm1 = Realm::get_shared_realm(config);
        config.execution_context = 1;
        auto realm2 = Realm::get_shared_realm(config);
        REQUIRE(realm1 != realm2);

        config.execution_context = util::none;
        auto realm3 = Realm::get_shared_realm(config);
        REQUIRE(realm1 != realm3);
        REQUIRE(realm2 != realm3);
    }

    SECTION("can use Realm with explicit execution context on different thread") {
        config.execution_context = 1;
        auto realm = Realm::get_shared_realm(config);
        std::thread([&]{
            REQUIRE_NOTHROW(realm->verify_thread());
        }).join();
    }

    SECTION("should get same instance for same explicit execution context on different thread") {
        config.execution_context = 1;
        auto realm1 = Realm::get_shared_realm(config);
        std::thread([&]{
            auto realm2 = Realm::get_shared_realm(config);
            REQUIRE(realm1 == realm2);
        }).join();
    }

    SECTION("should not modify the schema when fetching from the cache") {
        auto realm = Realm::get_shared_realm(config);
        auto object_schema = &*realm->schema().find("object");
        Realm::get_shared_realm(config);
        REQUIRE(object_schema == &*realm->schema().find("object"));
    }
}

TEST_CASE("SharedRealm: notifications") {
    if (!util::EventLoop::has_implementation())
        return;

    TestFile config;
    config.cache = false;
    config.schema_version = 0;
    config.schema = Schema{
        {"object", {
            {"value", PropertyType::Int}
        }},
    };

    struct Context : BindingContext {
        size_t* change_count;
        Context(size_t* out) : change_count(out) { }

        void did_change(std::vector<ObserverState> const&, std::vector<void*> const&, bool) override
        {
            ++*change_count;
        }
    };

    size_t change_count = 0;
    auto realm = Realm::get_shared_realm(config);
    realm->m_binding_context.reset(new Context{&change_count});
    realm->m_binding_context->realm = realm;

    SECTION("local notifications are sent synchronously") {
        realm->begin_transaction();
        REQUIRE(change_count == 0);
        realm->commit_transaction();
        REQUIRE(change_count == 1);
    }

    SECTION("remote notifications are sent asynchronously") {
        auto r2 = Realm::get_shared_realm(config);
        r2->begin_transaction();
        r2->commit_transaction();
        REQUIRE(change_count == 0);
        util::EventLoop::main().run_until([&]{ return change_count > 0; });
        REQUIRE(change_count == 1);
    }

    SECTION("refresh() from within changes_available() refreshes") {
        struct Context : BindingContext {
            Realm& realm;
            Context(Realm& realm) : realm(realm) { }

            void changes_available() override
            {
                REQUIRE(realm.refresh());
            }
        };
        realm->m_binding_context.reset(new Context{*realm});
        realm->set_auto_refresh(false);

        auto r2 = Realm::get_shared_realm(config);
        r2->begin_transaction();
        r2->commit_transaction();
        realm->notify();
        // Should return false as the realm was already advanced
        REQUIRE_FALSE(realm->refresh());
    }

    SECTION("refresh() from within did_change() is a no-op") {
        struct Context : BindingContext {
            Realm& realm;
            Context(Realm& realm) : realm(realm) { }

            void did_change(std::vector<ObserverState> const&, std::vector<void*> const&, bool) override
            {
                // Create another version so that refresh() could do something
                auto r2 = Realm::get_shared_realm(realm.config());
                r2->begin_transaction();
                r2->commit_transaction();

                // Should be a no-op
                REQUIRE_FALSE(realm.refresh());
            }
        };
        realm->m_binding_context.reset(new Context{*realm});

        auto r2 = Realm::get_shared_realm(config);
        r2->begin_transaction();
        r2->commit_transaction();
        REQUIRE(realm->refresh());

        realm->m_binding_context.reset();
        // Should advance to the version created in the previous did_change()
        REQUIRE(realm->refresh());
        // No more versions, so returns false
        REQUIRE_FALSE(realm->refresh());
    }

    SECTION("begin_write() from within did_change() produces recursive notifications") {
        struct Context : BindingContext {
            Realm& realm;
            size_t calls = 0;
            Context(Realm& realm) : realm(realm) { }

            void did_change(std::vector<ObserverState> const&, std::vector<void*> const&, bool) override
            {
                ++calls;
                if (realm.is_in_transaction())
                    return;

                // Create another version so that begin_write() advances the version
                auto r2 = Realm::get_shared_realm(realm.config());
                r2->begin_transaction();
                r2->commit_transaction();

                realm.begin_transaction();
                realm.cancel_transaction();
            }
        };
        auto context = new Context{*realm};
        realm->m_binding_context.reset(context);

        auto r2 = Realm::get_shared_realm(config);
        r2->begin_transaction();
        r2->commit_transaction();
        REQUIRE(realm->refresh());
        REQUIRE(context->calls == 2);

        // Despite not sending a new notification we did advance the version, so
        // no more versions to refresh to
        REQUIRE_FALSE(realm->refresh());
    }
}

TEST_CASE("SharedRealm: schema updating from external changes") {
    TestFile config;
    config.cache = false;
    config.schema_version = 0;
    config.schema_mode = SchemaMode::Additive;
    config.schema = Schema{
        {"object", {
            {"value", PropertyType::Int, Property::IsPrimary{true}},
            {"value 2", PropertyType::Int, Property::IsPrimary{false}, Property::IsIndexed{true}},
        }},
    };

    SECTION("newly added columns update table columns but are not added to properties") {
        auto r1 = Realm::get_shared_realm(config);
        auto r2 = Realm::get_shared_realm(config);
        auto test = [&] {
            r2->begin_transaction();
            r2->read_group().get_table("class_object")->insert_column(0, type_String, "new col");
            r2->commit_transaction();

            auto& object_schema = *r1->schema().find("object");
            REQUIRE(object_schema.persisted_properties.size() == 2);
            REQUIRE(object_schema.persisted_properties[0].table_column == 0);
            r1->refresh();
            REQUIRE(object_schema.persisted_properties[0].table_column == 1);
        };
        SECTION("with an active read transaction") {
            r1->read_group();
            test();
        }
        SECTION("without an active read transaction") {
            r1->invalidate();
            test();
        }
    }

    SECTION("beginning a read transaction checks for incompatible changes") {
        auto r = Realm::get_shared_realm(config);
        r->invalidate();

        auto& sg = TestHelper::get_shared_group(r);
        WriteTransaction wt(sg);
        auto& table = *wt.get_table("class_object");

        SECTION("removing a property") {
            table.remove_column(0);
            wt.commit();
            REQUIRE_THROWS_WITH(r->refresh(),
                                Catch::Matchers::Contains("Property 'object.value' has been removed."));
        }

        SECTION("change property type") {
            table.remove_column(1);
            table.add_column(type_Float, "value 2");
            wt.commit();
            REQUIRE_THROWS_WITH(r->refresh(),
                                Catch::Matchers::Contains("Property 'object.value 2' has been changed from 'int' to 'float'"));
        }

        SECTION("make property optional") {
            table.remove_column(1);
            table.add_column(type_Int, "value 2", true);
            wt.commit();
            REQUIRE_THROWS_WITH(r->refresh(),
                                Catch::Matchers::Contains("Property 'object.value 2' has been made optional"));
        }

        SECTION("recreate column with no changes") {
            table.remove_column(1);
            table.add_column(type_Int, "value 2");
            wt.commit();
            REQUIRE_NOTHROW(r->refresh());
        }

        SECTION("remove index from non-PK") {
            table.remove_search_index(1);
            wt.commit();
            REQUIRE_NOTHROW(r->refresh());
        }
    }
}

TEST_CASE("SharedRealm: closed realm") {
    TestFile config;
    config.schema_version = 1;
    config.schema = Schema{
        {"object", {
            {"value", PropertyType::Int}
        }},
    };

    auto realm = Realm::get_shared_realm(config);
    realm->close();

    REQUIRE(realm->is_closed());

    REQUIRE_THROWS_AS(realm->read_group(), ClosedRealmException);
    REQUIRE_THROWS_AS(realm->begin_transaction(), ClosedRealmException);
    REQUIRE(!realm->is_in_transaction());
    REQUIRE_THROWS_AS(realm->commit_transaction(), InvalidTransactionException);
    REQUIRE_THROWS_AS(realm->cancel_transaction(), InvalidTransactionException);

    REQUIRE_THROWS_AS(realm->refresh(), ClosedRealmException);
    REQUIRE_THROWS_AS(realm->invalidate(), ClosedRealmException);
    REQUIRE_THROWS_AS(realm->compact(), ClosedRealmException);
}

TEST_CASE("ShareRealm: in-memory mode from buffer") {
    TestFile config;
    config.schema_version = 1;
    config.schema = Schema{
        {"object", {
            {"value", PropertyType::Int}
        }},
    };

    SECTION("Save and open Realm from in-memory buffer") {
        // Write in-memory copy of Realm to a buffer
        auto realm = Realm::get_shared_realm(config);
        OwnedBinaryData realm_buffer = realm->write_copy();

        // Open the buffer as a new (immutable in-memory) Realm
        realm::Realm::Config config2;
        config2.in_memory = true;
        config2.schema_mode = SchemaMode::Immutable;
        config2.realm_data = realm_buffer.get();

        auto realm2 = Realm::get_shared_realm(config2);

        // Verify that it can read the schema and that it is the same
        REQUIRE(realm->schema().size() == 1);
        auto it = realm->schema().find("object");
        REQUIRE(it != realm->schema().end());
        REQUIRE(it->persisted_properties.size() == 1);
        REQUIRE(it->persisted_properties[0].name == "value");
        REQUIRE(it->persisted_properties[0].table_column == 0);

        // Test invalid configs
        realm::Realm::Config config3;
        config3.realm_data = realm_buffer.get();
        REQUIRE_THROWS(Realm::get_shared_realm(config3)); // missing in_memory and immutable

        config3.in_memory = true;
        config3.schema_mode = SchemaMode::Immutable;
        config3.path = "path";
        REQUIRE_THROWS(Realm::get_shared_realm(config3)); // both buffer and path

        config3.path = "";
        config3.encryption_key = {'a'};
        REQUIRE_THROWS(Realm::get_shared_realm(config3)); // both buffer and encryption
    }
}

TEST_CASE("ShareRealm: realm closed in did_change callback") {
    TestFile config;
    config.schema_version = 1;
    config.schema = Schema{
        {"object", {
            {"value", PropertyType::Int}
        }},
    };
    config.cache = false;
    config.automatic_change_notifications = false;
    auto r1 = Realm::get_shared_realm(config);

    r1->begin_transaction();
    auto table = r1->read_group().get_table("class_object");
    table->add_empty_row();
    r1->commit_transaction();

    // Cannot be a member var of Context since Realm.close will free the context.
    static SharedRealm* shared_realm;
    shared_realm = &r1;
    struct Context : public BindingContext {
        void did_change(std::vector<ObserverState> const&, std::vector<void*> const&, bool) override
        {
            (*shared_realm)->close();
            (*shared_realm).reset();
        }
    };

    SECTION("did_change") {
        r1->m_binding_context.reset(new Context());
        r1->invalidate();

        auto r2 = Realm::get_shared_realm(config);
        r2->begin_transaction();
        r2->read_group().get_table("class_object")->add_empty_row(1);
        r2->commit_transaction();
        r2.reset();

        r1->notify();
    }

    SECTION("did_change with async results") {
        r1->m_binding_context.reset(new Context());
        Results results(r1, table->where());
        auto token = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
            // Should not be called.
            REQUIRE(false);
        });

        auto r2 = Realm::get_shared_realm(config);
        r2->begin_transaction();
        r2->read_group().get_table("class_object")->add_empty_row(1);
        r2->commit_transaction();
        r2.reset();

        auto coordinator = _impl::RealmCoordinator::get_existing_coordinator(config.path);
        coordinator->on_change();

        r1->notify();
    }

    SECTION("refresh") {
        r1->m_binding_context.reset(new Context());

        auto r2 = Realm::get_shared_realm(config);
        r2->begin_transaction();
        r2->read_group().get_table("class_object")->add_empty_row(1);
        r2->commit_transaction();
        r2.reset();

        REQUIRE_FALSE(r1->refresh());
    }

    shared_realm = nullptr;
}

TEST_CASE("RealmCoordinator: schema cache") {
    TestFile config;
    auto coordinator = _impl::RealmCoordinator::get_coordinator(config.path);

    Schema cache_schema;
    uint64_t cache_sv = -1, cache_tv = -1;

    Schema schema{
        {"object", {
            {"value", PropertyType::Int}
        }},
    };
    Schema schema2{
        {"object", {
            {"value", PropertyType::Int},
        }},
        {"object 2", {
            {"value", PropertyType::Int},
        }},
    };

    SECTION("valid initial schema sets cache") {
        coordinator->cache_schema(schema, 5, 10);
        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_schema == schema);
        REQUIRE(cache_sv == 5);
        REQUIRE(cache_tv == 10);
    }

    SECTION("cache can be updated with newer schema") {
        coordinator->cache_schema(schema, 5, 10);
        coordinator->cache_schema(schema2, 6, 11);
        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_schema == schema2);
        REQUIRE(cache_sv == 6);
        REQUIRE(cache_tv == 11);
    }

    SECTION("empty schema is ignored") {
        coordinator->cache_schema(Schema{}, 5, 10);
        REQUIRE_FALSE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));

        coordinator->cache_schema(schema, 5, 10);
        coordinator->cache_schema(Schema{}, 5, 10);
        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_schema == schema);
        REQUIRE(cache_sv == 5);
        REQUIRE(cache_tv == 10);
    }

    SECTION("schema for older transaction is ignored") {
        coordinator->cache_schema(schema, 5, 10);
        coordinator->cache_schema(schema2, 4, 8);

        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_schema == schema);
        REQUIRE(cache_sv == 5);
        REQUIRE(cache_tv == 10);

        coordinator->advance_schema_cache(10, 20);
        coordinator->cache_schema(schema, 6, 15);
        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_tv == 20); // should not have dropped to 15
    }

    SECTION("advance_schema() from transaction version bumps transaction version") {
        coordinator->cache_schema(schema, 5, 10);
        coordinator->advance_schema_cache(10, 12);
        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_schema == schema);
        REQUIRE(cache_sv == 5);
        REQUIRE(cache_tv == 12);
    }

    SECTION("advance_schema() ending before transaction version does nothing") {
        coordinator->cache_schema(schema, 5, 10);
        coordinator->advance_schema_cache(8, 9);
        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_schema == schema);
        REQUIRE(cache_sv == 5);
        REQUIRE(cache_tv == 10);
    }

    SECTION("advance_schema() extending over transaction version bumps version") {
        coordinator->cache_schema(schema, 5, 10);
        coordinator->advance_schema_cache(3, 15);
        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_schema == schema);
        REQUIRE(cache_sv == 5);
        REQUIRE(cache_tv == 15);
    }

    SECTION("advance_schema() with no cahced schema does nothing") {
        coordinator->advance_schema_cache(3, 15);
        REQUIRE_FALSE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
    }
}

TEST_CASE("SharedRealm: coordinator schema cache") {
    TestFile config;
    config.cache = false;
    auto r = Realm::get_shared_realm(config);
    auto coordinator = _impl::RealmCoordinator::get_existing_coordinator(config.path);

    Schema cache_schema;
    uint64_t cache_sv = -1, cache_tv = -1;

    Schema schema{
        {"object", {
            {"value", PropertyType::Int}
        }},
    };
    Schema schema2{
        {"object", {
            {"value", PropertyType::Int},
        }},
        {"object 2", {
            {"value", PropertyType::Int},
        }},
    };

    class ExternalWriter {
    private:
        std::unique_ptr<Replication> history;
        std::unique_ptr<SharedGroup> shared_group;
        std::unique_ptr<Group> read_only_group;

    public:
        WriteTransaction wt;
        ExternalWriter(Realm::Config const& config)
        : wt([&]() -> SharedGroup& {
            Realm::open_with_config(config, history, shared_group, read_only_group, nullptr);
            return *shared_group;
        }())
        {
        }
    };

    auto external_write = [&](Realm::Config const& config, auto&& fn) {
        ExternalWriter wt(config);
        fn(wt.wt);
        wt.wt.commit();
    };

    SECTION("is initially empty for uninitialized file") {
        REQUIRE_FALSE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
    }
    r->update_schema(schema);

    SECTION("is empty after calling update_schema()") {
        REQUIRE_FALSE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
    }

    Realm::get_shared_realm(config);
    SECTION("is populated after getting another Realm without a schema specified") {
        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_sv == 0);
        REQUIRE(cache_schema == schema);
        REQUIRE(cache_schema.begin()->persisted_properties[0].table_column == 0);
    }

    coordinator = nullptr;
    r = nullptr;
    r = Realm::get_shared_realm(config);
    coordinator = _impl::RealmCoordinator::get_existing_coordinator(config.path);
    REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));

    SECTION("is populated after opening an initialized file") {
        REQUIRE(cache_sv == 0);
        REQUIRE(cache_tv == 2); // with in-realm history the version doesn't reset
        REQUIRE(cache_schema == schema);
        REQUIRE(cache_schema.begin()->persisted_properties[0].table_column == 0);
    }

    SECTION("transaction version is bumped after a local write") {
        auto tv = cache_tv;
        r->begin_transaction();
        r->commit_transaction();
        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_tv == tv + 1);
    }

    SECTION("notify() without a read transaction does not bump transaction version") {
        auto tv = cache_tv;

        SECTION("non-schema change") {
            external_write(config, [](auto& wt) {
                wt.get_table("class_object")->add_empty_row();
            });
        }
        SECTION("schema change") {
            external_write(config, [](auto& wt) {
                wt.add_table("class_object 2");
            });
        }

        r->notify();
        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_tv == tv);
        REQUIRE(cache_schema == schema);
    }

    SECTION("notify() with a read transaction bumps transaction version") {
        r->read_group();
        external_write(config, [](auto& wt) {
            wt.get_table("class_object")->add_empty_row();
        });

        r->notify();
        auto tv = cache_tv;
        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_tv == tv + 1);
    }

    SECTION("notify() with a read transaction updates schema folloing external schema change") {
        r->read_group();
        external_write(config, [](auto& wt) {
            wt.add_table("class_object 2");
        });

        r->notify();
        auto tv = cache_tv;
        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_tv == tv + 1);
        REQUIRE(cache_schema.size() == 2);
        REQUIRE(cache_schema.find("object 2") != cache_schema.end());
    }

    SECTION("transaction version is bumped after refresh() following external non-schema write") {
        external_write(config, [](auto& wt) {
            wt.get_table("class_object")->add_empty_row();
        });

        r->refresh();
        auto tv = cache_tv;
        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_tv == tv + 1);
    }

    SECTION("schema is reread following refresh() over external schema change") {
        external_write(config, [](auto& wt) {
            wt.add_table("class_object 2");
        });

        r->refresh();
        auto tv = cache_tv;
        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_tv == tv + 1);
        REQUIRE(cache_schema.size() == 2);
        REQUIRE(cache_schema.find("object 2") != cache_schema.end());
    }

    SECTION("update_schema() to version already on disk updates cache") {
        r->read_group();
        external_write(config, [](auto& wt) {
            auto table = wt.add_table("class_object 2");
            table->add_column(type_Int, "value");
        });

        auto tv = cache_tv;
        r->update_schema(schema2);

        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_tv == tv + 1); // only +1 because update_schema() did not perform a write
        REQUIRE(cache_schema.size() == 2);
        REQUIRE(cache_schema.find("object 2") != cache_schema.end());
    }

    SECTION("update_schema() to version already on disk updates cache") {
        r->read_group();
        external_write(config, [](auto& wt) {
            auto table = wt.add_table("class_object 2");
            table->add_column(type_Int, "value");
        });

        auto tv = cache_tv;
        r->update_schema(schema2);

        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_tv == tv + 1); // only +1 because update_schema() did not perform a write
        REQUIRE(cache_schema.size() == 2);
        REQUIRE(cache_schema.find("object 2") != cache_schema.end());
    }

    SECTION("update_schema() to version populated on disk while waiting for the write lock updates cache") {
        r->read_group();

        // We want to commit the write while we're waiting on the write lock on
        // this thread, which can't really be done in a properly synchronized manner
        std::chrono::microseconds wait_time{5000};
#if REALM_ANDROID
        // When running on device or in an emulator we need to wait longer due
        // to them being slow
        wait_time *= 10;
#endif

        bool did_run = false;
        JoiningThread thread([&] {
            ExternalWriter writer(config);
            if (writer.wt.get_table("class_object 2"))
                return;
            did_run = true;

            auto table = writer.wt.add_table("class_object 2");
            table->add_column(type_Int, "value");
            std::this_thread::sleep_for(wait_time * 2);
            writer.wt.commit();
        });
        std::this_thread::sleep_for(wait_time);

        auto tv = cache_tv;
        r->update_schema(Schema{
            {"object", {{"value", PropertyType::Int}}},
            {"object 2", {{"value", PropertyType::Int}}},
        });

        // just skip the test if the timing was wrong to avoid spurious failures
        if (!did_run)
            return;

        REQUIRE(coordinator->get_cached_schema(cache_schema, cache_sv, cache_tv));
        REQUIRE(cache_tv == tv + 1); // only +1 because update_schema()'s write was rolled back
        REQUIRE(cache_schema.size() == 2);
        REQUIRE(cache_schema.find("object 2") != cache_schema.end());
    }
}

TEST_CASE("SharedRealm: dynamic schema mode doesn't invalidate object schema pointers when schema hasn't changed") {
    TestFile config;
    config.cache = false;

    // Prepopulate the Realm with the schema.
    Realm::Config config_with_schema = config;
    config_with_schema.schema_version = 1;
    config_with_schema.schema_mode = SchemaMode::Automatic;
    config_with_schema.schema = Schema{
        {"object", {
            {"value", PropertyType::Int, Property::IsPrimary{true}},
            {"value 2", PropertyType::Int, Property::IsPrimary{false}, Property::IsIndexed{true}},
        }}
    };
    auto r1 = Realm::get_shared_realm(config_with_schema);

    // Retrieve the object schema in dynamic mode.
    auto r2 = Realm::get_shared_realm(config);
    auto* object_schema = &*r2->schema().find("object");

    // Perform an empty write to create a new version, resulting in the other Realm needing to re-read the schema.
    r1->begin_transaction();
    r1->commit_transaction();

    // Advance to the latest version, and verify the object schema is at the same location in memory.
    r2->read_group();
    REQUIRE(object_schema == &*r2->schema().find("object"));
}

TEST_CASE("SharedRealm: SchemaChangedFunction") {
    struct Context : BindingContext {
        size_t* change_count;
        Schema* schema;
        Context(size_t* count_out, Schema* schema_out) : change_count(count_out), schema(schema_out) { }

        void schema_did_change(Schema const& changed_schema) override
        {
            ++*change_count;
            *schema = changed_schema;
        }
    };

    size_t schema_changed_called = 0;
    Schema changed_fixed_schema;
    TestFile config;
    config.cache = false;
    auto dynamic_config = config;

    config.schema = Schema{
        {"object1", {
            {"value", PropertyType::Int},
        }},
        {"object2", {
            {"value", PropertyType::Int},
        }}
    };
    config.schema_version = 1;
    auto r1 = Realm::get_shared_realm(config);
    r1->m_binding_context.reset(new Context(&schema_changed_called, &changed_fixed_schema));

    SECTION("Fixed schema") {
        SECTION("update_schema") {
            auto new_schema = Schema{
                {"object3", {
                    {"value", PropertyType::Int},
                }}
            };
            r1->update_schema(new_schema, 2);
            REQUIRE(schema_changed_called == 1);
            REQUIRE(changed_fixed_schema.find("object3")->property_for_name("value")->table_column == 0);
        }

        SECTION("Open a new Realm instance with same config won't trigger") {
            auto r2 = Realm::get_shared_realm(config);
            REQUIRE(schema_changed_called == 0);
        }

        SECTION("Non schema related transaction doesn't trigger") {
            auto r2 = Realm::get_shared_realm(config);
            r2->begin_transaction();
            r2->commit_transaction();
            r1->refresh();
            REQUIRE(schema_changed_called == 0);
        }

        SECTION("Schema is changed by another Realm") {
            auto r2 = Realm::get_shared_realm(config);
            r2->begin_transaction();
            r2->read_group().get_table("class_object1")->insert_column(0, type_String, "new col");
            r2->commit_transaction();
            r1->refresh();
            REQUIRE(schema_changed_called == 1);
            REQUIRE(changed_fixed_schema.find("object1")->property_for_name("value")->table_column == 1);
        }

        // This is not a valid use case. m_schema won't be refreshed.
        SECTION("Schema is changed by this Realm won't trigger") {
            r1->begin_transaction();
            r1->read_group().get_table("class_object1")->insert_column(0, type_String, "new col");
            r1->commit_transaction();
            REQUIRE(schema_changed_called == 0);
        }
    }

    SECTION("Dynamic schema") {
        size_t dynamic_schema_changed_called = 0;
        Schema changed_dynamic_schema;
        auto r2 = Realm::get_shared_realm(dynamic_config);
        r2->m_binding_context.reset(new Context(&dynamic_schema_changed_called, &changed_dynamic_schema));

        SECTION("set_schema_subset") {
            auto new_schema = Schema{
                {"object1", {
                    {"value", PropertyType::Int},
                }}
            };
            r2->set_schema_subset(new_schema);
            REQUIRE(schema_changed_called == 0);
            REQUIRE(dynamic_schema_changed_called == 1);
            REQUIRE(changed_dynamic_schema.find("object1")->property_for_name("value")->table_column == 0);
        }

        SECTION("Non schema related transaction will alway trigger in dynamic mode") {
            auto r1 = Realm::get_shared_realm(config);
            // An empty transaction will trigger the schema changes always in dynamic mode.
            r1->begin_transaction();
            r1->commit_transaction();
            r2->refresh();
            REQUIRE(dynamic_schema_changed_called == 1);
            REQUIRE(changed_dynamic_schema.find("object1")->property_for_name("value")->table_column == 0);
        }

        SECTION("Schema is changed by another Realm") {
            r1->begin_transaction();
            r1->read_group().get_table("class_object1")->insert_column(0, type_String, "new col");
            r1->commit_transaction();
            r2->refresh();
            REQUIRE(dynamic_schema_changed_called == 1);
            REQUIRE(changed_dynamic_schema.find("object1")->property_for_name("value")->table_column == 1);
        }
    }
}

#ifndef _WIN32
TEST_CASE("SharedRealm: compact on launch") {
    // Make compactable Realm
    TestFile config;
    config.cache = false;
    config.automatic_change_notifications = false;
    int num_opens = 0;
    config.should_compact_on_launch_function = [&](size_t total_bytes, size_t used_bytes) {
        REQUIRE(total_bytes > used_bytes);
        num_opens++;
        return num_opens != 2;
    };
    config.schema = Schema{
        {"object", {
            {"value", PropertyType::String}
        }},
    };
    REQUIRE(num_opens == 0);
    auto r = Realm::get_shared_realm(config);
    REQUIRE(num_opens == 1);
    r->begin_transaction();
    auto table = r->read_group().get_table("class_object");
    size_t count = 1000;
    table->add_empty_row(count);
    for (size_t i = 0; i < count; ++i)
        table->set_string(0, i, util::format("Foo_%1", i % 10).c_str());
    r->commit_transaction();
    REQUIRE(table->size() == count);
    r->close();

    SECTION("compact reduces the file size") {
        // Confirm expected sizes before and after opening the Realm
        size_t size_before = size_t(File(config.path).get_size());
        r = Realm::get_shared_realm(config);
        REQUIRE(num_opens == 2);
        r->close();
        REQUIRE(size_t(File(config.path).get_size()) == size_before); // File size after returning false
        r = Realm::get_shared_realm(config);
        REQUIRE(num_opens == 3);
        REQUIRE(size_t(File(config.path).get_size()) < size_before); // File size after returning true

        // Validate that the file still contains what it should
        REQUIRE(r->read_group().get_table("class_object")->size() == count);

        // Registering for a collection notification shouldn't crash when compact on launch is used.
        Results results(r, *r->read_group().get_table("class_object"));
        results.async([](std::exception_ptr) { });
        r->close();
    }

    SECTION("compact function does not get invoked if realm is open on another thread") {
        // Confirm expected sizes before and after opening the Realm
        size_t size_before = size_t(File(config.path).get_size());
        r = Realm::get_shared_realm(config);
        REQUIRE(num_opens == 2);
        std::thread([&]{
            auto r2 = Realm::get_shared_realm(config);
            REQUIRE(num_opens == 2);
        }).join();
        r->close();
        std::thread([&]{
            auto r3 = Realm::get_shared_realm(config);
            REQUIRE(num_opens == 3);
        }).join();
    }
}
#endif

struct ModeAutomatic {
    static SchemaMode mode() { return SchemaMode::Automatic; }
    static bool should_call_init_on_version_bump() { return false; }
};
struct ModeAdditive {
    static SchemaMode mode() { return SchemaMode::Additive; }
    static bool should_call_init_on_version_bump() { return false; }
};
struct ModeManual {
    static SchemaMode mode() { return SchemaMode::Manual; }
    static bool should_call_init_on_version_bump() { return false; }
};
struct ModeResetFile {
    static SchemaMode mode() { return SchemaMode::ResetFile; }
    static bool should_call_init_on_version_bump() { return true; }
};

TEMPLATE_TEST_CASE("SharedRealm: update_schema with initialization_function",
                   ModeAutomatic, ModeAdditive, ModeManual, ModeResetFile) {
    TestFile config;
    config.schema_mode = TestType::mode();
    bool initialization_function_called = false;
    uint64_t schema_version_in_callback = -1;
    Schema schema_in_callback;
    auto initialization_function = [&initialization_function_called, &schema_version_in_callback,
                                    &schema_in_callback](auto shared_realm) {
        REQUIRE(shared_realm->is_in_transaction());
        initialization_function_called = true;
        schema_version_in_callback = shared_realm->schema_version();
        schema_in_callback = shared_realm->schema();
    };

    Schema schema{
        {"object", {
            {"value", PropertyType::String}
        }},
    };

    SECTION("call initialization function directly by update_schema") {
        // Open in dynamic mode with no schema specified
        auto realm = Realm::get_shared_realm(config);
        REQUIRE_FALSE(initialization_function_called);

        realm->update_schema(schema, 0, nullptr, initialization_function);
        REQUIRE(initialization_function_called);
        REQUIRE(schema_version_in_callback == 0);
        REQUIRE(schema_in_callback.compare(schema).size() == 0);
    }

    config.schema_version = 0;
    config.schema = schema;

    SECTION("initialization function should be called for unversioned realm") {
        config.initialization_function = initialization_function;
        Realm::get_shared_realm(config);
        REQUIRE(initialization_function_called);
        REQUIRE(schema_version_in_callback == 0);
        REQUIRE(schema_in_callback.compare(schema).size() == 0);
    }

    SECTION("initialization function for versioned realm") {
        // Initialize v0
        Realm::get_shared_realm(config);

        config.schema_version = 1;
        config.initialization_function = initialization_function;
        Realm::get_shared_realm(config);
        REQUIRE(initialization_function_called == TestType::should_call_init_on_version_bump());
        if (TestType::should_call_init_on_version_bump()) {
            REQUIRE(schema_version_in_callback == 1);
            REQUIRE(schema_in_callback.compare(schema).size() == 0);
        }
    }
}

TEST_CASE("BindingContext is notified about delivery of change notifications") {
    _impl::RealmCoordinator::assert_no_open_realms();

    InMemoryTestFile config;
    config.cache = false;
    config.automatic_change_notifications = false;

    auto r = Realm::get_shared_realm(config);
    r->update_schema({
        {"object", {
            {"value", PropertyType::Int}
        }},
    });

    auto coordinator = _impl::RealmCoordinator::get_existing_coordinator(config.path);
    auto table = r->read_group().get_table("class_object");

    SECTION("BindingContext notified even if no callbacks are registered") {
        static int binding_context_start_notify_calls = 0;
        static int binding_context_end_notify_calls = 0;
        struct Context : BindingContext {
            void will_send_notifications() override
            {
                ++binding_context_start_notify_calls;
            }

            void did_send_notifications() override
            {
                ++binding_context_end_notify_calls;
            }
        };
        r->m_binding_context.reset(new Context());

        SECTION("local commit") {
            binding_context_start_notify_calls = 0;
            binding_context_end_notify_calls = 0;
            coordinator->on_change();
            r->begin_transaction();
            REQUIRE(binding_context_start_notify_calls == 1);
            REQUIRE(binding_context_end_notify_calls == 1);
            r->cancel_transaction();
        }

        SECTION("remote commit") {
            binding_context_start_notify_calls = 0;
            binding_context_end_notify_calls = 0;
            JoiningThread([&] {
                auto r2 = coordinator->get_realm();
                r2->begin_transaction();
                auto table2 = r2->read_group().get_table("class_object");
                table2->add_empty_row();
                r2->commit_transaction();
            });
            advance_and_notify(*r);
            REQUIRE(binding_context_start_notify_calls == 1);
            REQUIRE(binding_context_end_notify_calls == 1);
        }
    }

    SECTION("notify BindingContext before and after sending notifications") {
        static int binding_context_start_notify_calls = 0;
        static int binding_context_end_notify_calls = 0;
        static int notification_calls = 0;

        Results results1(r, table->where().greater_equal(0, 0));
        Results results2(r, table->where().less(0, 10));

        auto token1 = results1.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            ++notification_calls;
        });

        auto token2 = results2.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            ++notification_calls;
        });

        struct Context : BindingContext {
            void will_send_notifications() override
            {
                REQUIRE(notification_calls == 0);
                REQUIRE(binding_context_end_notify_calls == 0);
                ++binding_context_start_notify_calls;
            }

            void did_send_notifications() override
            {
                REQUIRE(notification_calls == 2);
                REQUIRE(binding_context_start_notify_calls == 1);
                ++binding_context_end_notify_calls;
            }
        };
        r->m_binding_context.reset(new Context());

        SECTION("local commit") {
            binding_context_start_notify_calls = 0;
            binding_context_end_notify_calls = 0;
            notification_calls = 0;
            coordinator->on_change();
            r->begin_transaction();
            table->add_empty_row();
            r->commit_transaction();
            REQUIRE(binding_context_start_notify_calls == 1);
            REQUIRE(binding_context_end_notify_calls == 1);
        }

        SECTION("remote commit") {
            binding_context_start_notify_calls = 0;
            binding_context_end_notify_calls = 0;
            notification_calls = 0;
            JoiningThread([&] {
                auto r2 = coordinator->get_realm();
                r2->begin_transaction();
                auto table2 = r2->read_group().get_table("class_object");
                table2->add_empty_row();
                r2->commit_transaction();
            });
            advance_and_notify(*r);
            REQUIRE(binding_context_start_notify_calls == 1);
            REQUIRE(binding_context_end_notify_calls == 1);
        }
    }

    SECTION("did_send() is skipped if the Realm is closed first") {
        Results results(r, table->where());
        bool do_close = true;
        auto token = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
            if (do_close)
                r->close();
        });

        struct FailOnDidSend : BindingContext {
            void did_send_notifications() override
            {
                FAIL("did_send_notifications() should not have been called");
            }
        };
        struct CloseOnWillChange : FailOnDidSend {
            Realm& realm;
            CloseOnWillChange(Realm& realm) : realm(realm) {}

            void will_send_notifications() override
            {
                realm.close();
            }
        };

        SECTION("closed in notification callback for notify()") {
            r->m_binding_context.reset(new FailOnDidSend);
            coordinator->on_change();
            r->notify();
        }

        SECTION("closed in notification callback for refresh()") {
            do_close = false;
            coordinator->on_change();
            r->notify();
            do_close = true;

            JoiningThread([&] {
                auto r = coordinator->get_realm();
                r->begin_transaction();
                r->read_group().get_table("class_object")->add_empty_row();
                r->commit_transaction();
            });

            r->m_binding_context.reset(new FailOnDidSend);
            coordinator->on_change();
            r->refresh();
        }

        SECTION("closed in will_send() for notify()") {
            r->m_binding_context.reset(new CloseOnWillChange(*r));
            coordinator->on_change();
            r->notify();
        }

        SECTION("closed in will_send() for refresh()") {
            do_close = false;
            coordinator->on_change();
            r->notify();
            do_close = true;

            JoiningThread([&] {
                auto r = coordinator->get_realm();
                r->begin_transaction();
                r->read_group().get_table("class_object")->add_empty_row();
                r->commit_transaction();
            });

            r->m_binding_context.reset(new CloseOnWillChange(*r));
            coordinator->on_change();
            r->refresh();
        }
    }
}

TEST_CASE("Statistics on Realms") {
    _impl::RealmCoordinator::assert_no_open_realms();

    InMemoryTestFile config;
    config.cache = false;
    config.automatic_change_notifications = false;

    auto r = Realm::get_shared_realm(config);
    r->update_schema({
        {"object", {
            {"value", PropertyType::Int}
        }},
    });

    SECTION("compute_size") {
        auto s = r->compute_size();
        REQUIRE(s > 0);
    }
}

#if REALM_PLATFORM_APPLE
TEST_CASE("BindingContext is notified in case of notifier errors") {
    _impl::RealmCoordinator::assert_no_open_realms();

    class OpenFileLimiter {
    public:
        OpenFileLimiter()
        {
            // Set the max open files to zero so that opening new files will fail
            getrlimit(RLIMIT_NOFILE, &m_old);
            rlimit rl = m_old;
            rl.rlim_cur = 0;
            setrlimit(RLIMIT_NOFILE, &rl);
        }

        ~OpenFileLimiter()
        {
            setrlimit(RLIMIT_NOFILE, &m_old);
        }

    private:
        rlimit m_old;
    };

    InMemoryTestFile config;
    config.cache = false;
    config.automatic_change_notifications = false;

    auto r = Realm::get_shared_realm(config);
    r->update_schema({
      {"object", {
        {"value", PropertyType::Int}
      }},
    });

    auto coordinator = _impl::RealmCoordinator::get_existing_coordinator(config.path);
    auto table = r->read_group().get_table("class_object");
    Results results(r, *r->read_group().get_table("class_object"));
    static int binding_context_start_notify_calls = 0;
    static int binding_context_end_notify_calls = 0;
    static bool error_called = false;
    struct Context : BindingContext {
        void will_send_notifications() override
        {
            REQUIRE_FALSE(error_called);
            ++binding_context_start_notify_calls;
        }

        void did_send_notifications() override
        {
            REQUIRE(error_called);
            ++binding_context_end_notify_calls;
        }
    };
    r->m_binding_context.reset(new Context());

    SECTION("realm on background thread could not be opened") {
        OpenFileLimiter limiter;

        auto token = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
            REQUIRE(err);
            REQUIRE_FALSE(error_called);
            error_called = true;
        });
        advance_and_notify(*r);
        REQUIRE(error_called);
        REQUIRE(binding_context_start_notify_calls == 1);
        REQUIRE(binding_context_end_notify_calls == 1);
    }
}
#endif
