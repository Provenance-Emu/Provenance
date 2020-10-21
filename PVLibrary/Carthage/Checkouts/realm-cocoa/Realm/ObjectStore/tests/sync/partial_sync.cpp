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

#include "feature_checks.hpp"


#include "sync_test_utils.hpp"

#include "shared_realm.hpp"
#include "object.hpp"
#include "object_schema.hpp"
#include "object_store.hpp"
#include "results.hpp"
#include "schema.hpp"

#include "impl/object_accessor_impl.hpp"
#include "sync/subscription_state.hpp"
#include "sync/partial_sync.hpp"

#include "sync/sync_config.hpp"
#include "sync/sync_manager.hpp"
#include "sync/sync_session.hpp"

#include "util/event_loop.hpp"
#include "util/test_file.hpp"
#include <realm/parser/parser.hpp>
#include <realm/parser/query_builder.hpp>
#include <realm/util/optional.hpp>

using namespace realm;
using namespace std::string_literals;

struct TypeA {
    size_t number;
    size_t second_number;
    std::string string;
};

struct TypeB {
    size_t number;
    std::string string;
    std::string second_string;
};

enum class PartialSyncTestObjects { A, B };

// Test helpers.
namespace {

Schema partial_sync_schema()
{
    return Schema{
        {"object_a", {
            {"number", PropertyType::Int},
            {"second_number", PropertyType::Int},
            {"string", PropertyType::String},
            {"link", PropertyType::Object|PropertyType::Nullable, "link_target"},
        }},
        {"object_b", {
            {"number", PropertyType::Int},
            {"string", PropertyType::String},
            {"second_string", PropertyType::String},
        }},
        {"link_target", {
            {"id", PropertyType::Int}
        }}
    };
}

void populate_realm(Realm::Config& config, std::vector<TypeA> a={}, std::vector<TypeB> b={})
{
    auto r = Realm::get_shared_realm(config);
    r->begin_transaction();
    {
        const auto& object_schema = *r->schema().find("object_a");
        const auto& number_prop = *object_schema.property_for_name("number");
        const auto& second_number_prop = *object_schema.property_for_name("second_number");
        const auto& string_prop = *object_schema.property_for_name("string");
        TableRef table = ObjectStore::table_for_object_type(r->read_group(), "object_a");
        for (auto& current : a) {
            size_t row_idx = sync::create_object(r->read_group(), *table);
            table->set_int(number_prop.table_column, row_idx, current.number);
            table->set_int(second_number_prop.table_column, row_idx, current.second_number);
            table->set_string(string_prop.table_column, row_idx, current.string);
        }
    }
    {
        const auto& object_schema = *r->schema().find("object_b");
        const auto& number_prop = *object_schema.property_for_name("number");
        const auto& string_prop = *object_schema.property_for_name("string");
        const auto& second_string_prop = *object_schema.property_for_name("second_string");
        TableRef table = ObjectStore::table_for_object_type(r->read_group(), "object_b");
        for (auto& current : b) {
            size_t row_idx = sync::create_object(r->read_group(), *table);
            table->set_int(number_prop.table_column, row_idx, current.number);
            table->set_string(string_prop.table_column, row_idx, current.string);
            table->set_string(second_string_prop.table_column, row_idx, current.second_string);
        }
    }
    {
        const auto& object_schema = *r->schema().find("link_target");
        const auto& id_prop = *object_schema.property_for_name("id");
        TableRef table = ObjectStore::table_for_object_type(r->read_group(), "link_target");

        size_t row_idx = sync::create_object(r->read_group(), *table);
        table->set_int(id_prop.table_column, row_idx, 0);
    }
    r->commit_transaction();
    // Wait for uploads
    std::atomic<bool> upload_done(false);
    auto session = SyncManager::shared().get_existing_active_session(config.path);
    session->wait_for_upload_completion([&](auto) { upload_done = true; });
    EventLoop::main().run_until([&] { return upload_done.load(); });
}

auto results_for_query(std::string const& query_string, Realm::Config const& config, std::string const& object_type)
{
    auto realm = Realm::get_shared_realm(config);
    auto table = ObjectStore::table_for_object_type(realm->read_group(), object_type);
    Query query = table->where();
    auto parser_result = realm::parser::parse(query_string);
    query_builder::NoArguments no_args;
    query_builder::apply_predicate(query, parser_result.predicate, no_args);

    DescriptorOrdering ordering;
    query_builder::apply_ordering(ordering, table, parser_result.ordering);
    return Results(std::move(realm), std::move(query), std::move(ordering));
}

partial_sync::Subscription subscribe_and_wait(Results results, util::Optional<std::string> name,
                                              std::function<void(Results, std::exception_ptr)> check)
{
    auto subscription = partial_sync::subscribe(results, name);

    bool partial_sync_done = false;
    std::exception_ptr exception;
    auto token = subscription.add_notification_callback([&] {
        switch (subscription.state()) {
            case partial_sync::SubscriptionState::Creating:
            case partial_sync::SubscriptionState::Pending:
                // Ignore these. They're temporary states.
                break;
            case partial_sync::SubscriptionState::Error:
                exception = subscription.error();
                partial_sync_done = true;
                break;
            case partial_sync::SubscriptionState::Complete:
            case partial_sync::SubscriptionState::Invalidated:
                partial_sync_done = true;
                break;
            default:
                throw std::logic_error(util::format("Unexpected state: %1", static_cast<uint8_t>(subscription.state())));
        }
    });
    EventLoop::main().run_until([&] { return partial_sync_done; });
    check(std::move(results), std::move(exception));
    return subscription;
}

/// Run a partial sync query, wait for the results, and then perform checks.
auto subscribe_and_wait(std::string const& query, Realm::Config const& partial_config,
                        std::string const& object_type, util::Optional<std::string> name,
                        std::function<void(Results, std::exception_ptr)> check)
{
    auto results = results_for_query(query, partial_config, object_type);
    return subscribe_and_wait(std::move(results), std::move(name), std::move(check));
}

auto subscription_with_query(std::string const& query, Realm::Config const& partial_config,
                             std::string const& object_type, util::Optional<std::string> name)
{
    auto results = results_for_query(query, partial_config, object_type);
    return partial_sync::subscribe(std::move(results), name);
}

bool results_contains(Results& r, TypeA a)
{
    CppContext ctx;
    SharedRealm realm = r.get_realm();
    const ObjectSchema os = *realm->schema().find("object_a");
    for (size_t i = 0; i < r.size(); ++i) {
        Object obj(realm, os, r.get(i));
        size_t first = any_cast<int64_t>(obj.get_property_value<util::Any>(ctx, "number"));
        size_t second = any_cast<int64_t>(obj.get_property_value<util::Any>(ctx, "second_number"));
        auto str = any_cast<std::string>(obj.get_property_value<util::Any>(ctx, "string"));
        if (first == a.number && second == a.second_number && str == a.string)
            return true;
    }
    return false;
}

bool results_contains(Results& r, TypeB b)
{
    CppContext ctx;
    SharedRealm realm = r.get_realm();
    const ObjectSchema os = *realm->schema().find("object_b");
    for (size_t i = 0;  i < r.size(); ++i) {
        Object obj(realm, os, r.get(i));
        size_t number = any_cast<int64_t>(obj.get_property_value<util::Any>(ctx, "number"));
        auto first_str = any_cast<std::string>(obj.get_property_value<util::Any>(ctx, "string"));
        auto second_str = any_cast<std::string>(obj.get_property_value<util::Any>(ctx, "second_string"));
        if (number == b.number && first_str == b.string && second_str == b.second_string)
            return true;
    }
    return false;
}

}

TEST_CASE("Partial sync", "[sync]") {
    if (!EventLoop::has_implementation())
        return;

    SyncManager::shared().configure_file_system(tmp_dir(), SyncManager::MetadataMode::NoEncryption);

    SyncServer server;
    SyncTestFile config(server, "test");
    config.schema = partial_sync_schema();
    SyncTestFile partial_config(server, "test", true);
    partial_config.schema = partial_sync_schema();
    // Add some objects for test purposes.
    populate_realm(config,
        {{1, 10, "partial"}, {2, 2, "partial"}, {3, 8, "sync"}},
        {{3, "meela", "orange"}, {4, "jyaku", "kiwi"}, {5, "meela", "cherry"}, {6, "meela", "kiwi"}, {7, "jyaku", "orange"}}
        );

    SECTION("works in the most basic case") {
        // Open the partially synced Realm and run a query.
        subscribe_and_wait("string = \"partial\"", partial_config, "object_a", util::none, [](Results results, std::exception_ptr) {
            REQUIRE(results.size() == 2);
            REQUIRE(results_contains(results, {1, 10, "partial"}));
            REQUIRE(results_contains(results, {2, 2, "partial"}));
        });
    }

    SECTION("works when multiple queries are made on the same property") {
        subscribe_and_wait("number > 1", partial_config, "object_a", util::none, [](Results results, std::exception_ptr) {
            REQUIRE(results.size() == 2);
            REQUIRE(results_contains(results, {2, 2, "partial"}));
            REQUIRE(results_contains(results, {3, 8, "sync"}));
        });

        subscribe_and_wait("number = 1", partial_config, "object_a", util::none, [](Results results, std::exception_ptr) {
            REQUIRE(results.size() == 1);
            REQUIRE(results_contains(results, {1, 10, "partial"}));
        });
    }

    SECTION("works when sort ascending and distinct are applied") {
        auto realm = Realm::get_shared_realm(partial_config);
        auto table = ObjectStore::table_for_object_type(realm->read_group(), "object_b");
        bool ascending = true;
        Results partial_conditions(realm, *table);
        partial_conditions = partial_conditions.sort({{"number", ascending}}).distinct({"string"});
        partial_sync::Subscription subscription = subscribe_and_wait(partial_conditions, util::none, [](Results results, std::exception_ptr) {
                REQUIRE(results.size() == 2);
                REQUIRE(results_contains(results, {3, "meela", "orange"}));
                REQUIRE(results_contains(results, {4, "jyaku", "kiwi"}));
        });
        auto partial_realm = Realm::get_shared_realm(partial_config);
        auto partial_table = ObjectStore::table_for_object_type(partial_realm->read_group(), "object_b");
        REQUIRE(partial_table);
        REQUIRE(partial_table->size() == 2);
        Results partial_results(partial_realm, *partial_table);
        REQUIRE(partial_results.size() == 2);
        REQUIRE(results_contains(partial_results, {3, "meela", "orange"}));
        REQUIRE(results_contains(partial_results, {4, "jyaku", "kiwi"}));
    }

    SECTION("works when sort descending and distinct are applied") {
        auto realm = Realm::get_shared_realm(partial_config);
        auto table = ObjectStore::table_for_object_type(realm->read_group(), "object_b");
        bool ascending = false;
        Results partial_conditions(realm, *table);
        partial_conditions = partial_conditions.sort({{"number", ascending}}).distinct({"string"});
        subscribe_and_wait(partial_conditions, util::none, [](Results results, std::exception_ptr) {
            REQUIRE(results.size() == 2);
            REQUIRE(results_contains(results, {6, "meela", "kiwi"}));
            REQUIRE(results_contains(results, {7, "jyaku", "orange"}));
        });
        auto partial_realm = Realm::get_shared_realm(partial_config);
        auto partial_table = ObjectStore::table_for_object_type(partial_realm->read_group(), "object_b");
        REQUIRE(partial_table);
        REQUIRE(partial_table->size() == 2);
        Results partial_results(partial_realm, *partial_table);
        REQUIRE(partial_results.size() == 2);
        REQUIRE(results_contains(partial_results, {6, "meela", "kiwi"}));
        REQUIRE(results_contains(partial_results, {7, "jyaku", "orange"}));
    }

    SECTION("works when queries are made on different properties") {
        subscribe_and_wait("string = \"jyaku\"", partial_config, "object_b", util::none, [](Results results, std::exception_ptr) {
            REQUIRE(results.size() == 2);
            REQUIRE(results_contains(results, {4, "jyaku", "kiwi"}));
            REQUIRE(results_contains(results, {7, "jyaku", "orange"}));
        });

        subscribe_and_wait("second_string = \"cherry\"", partial_config, "object_b", util::none, [](Results results, std::exception_ptr) {
            REQUIRE(results.size() == 1);
            REQUIRE(results_contains(results, {5, "meela", "cherry"}));
        });
    }

    SECTION("works when queries are made on different object types") {
        subscribe_and_wait("second_number < 9", partial_config, "object_a", util::none, [](Results results, std::exception_ptr) {
            REQUIRE(results.size() == 2);
            REQUIRE(results_contains(results, {2, 2, "partial"}));
            REQUIRE(results_contains(results, {3, 8, "sync"}));
        });

        subscribe_and_wait("string = \"meela\"", partial_config, "object_b", util::none, [](Results results, std::exception_ptr) {
            REQUIRE(results.size() == 3);
            REQUIRE(results_contains(results, {3, "meela", "orange"}));
            REQUIRE(results_contains(results, {5, "meela", "cherry"}));
            REQUIRE(results_contains(results, {6, "meela", "kiwi"}));
        });
    }

    SECTION("re-registering the same query with no name on the same type should succeed") {
        subscribe_and_wait("number > 1", partial_config, "object_a", util::none, [](Results results, std::exception_ptr error) {
            REQUIRE(!error);
            REQUIRE(results.size() == 2);
            REQUIRE(results_contains(results, {2, 2, "partial"}));
            REQUIRE(results_contains(results, {3, 8, "sync"}));
        });

        subscribe_and_wait("number > 1", partial_config, "object_a", util::none, [](Results results, std::exception_ptr error) {
            REQUIRE(!error);
            REQUIRE(results.size() == 2);
            REQUIRE(results_contains(results, {2, 2, "partial"}));
            REQUIRE(results_contains(results, {3, 8, "sync"}));
        });
    }

    SECTION("re-registering the same query with the same name on the same type should succeed") {
        subscribe_and_wait("number > 1", partial_config, "object_a", "query"s, [](Results results, std::exception_ptr error) {
            REQUIRE(!error);
            REQUIRE(results.size() == 2);
            REQUIRE(results_contains(results, {2, 2, "partial"}));
            REQUIRE(results_contains(results, {3, 8, "sync"}));
        });

        subscribe_and_wait("number > 1", partial_config, "object_a", "query"s, [](Results results, std::exception_ptr error) {
            REQUIRE(!error);
            REQUIRE(results.size() == 2);
            REQUIRE(results_contains(results, {2, 2, "partial"}));
            REQUIRE(results_contains(results, {3, 8, "sync"}));
        });
    }

    SECTION("unnamed query can be unsubscribed while in creating state") {
        auto subscription = subscription_with_query("number > 1", partial_config, "object_a", util::none);

        bool partial_sync_done = false;
        auto token = subscription.add_notification_callback([&] {
            using SubscriptionState = partial_sync::SubscriptionState;

            switch (subscription.state()) {
                case SubscriptionState::Creating:
                    partial_sync::unsubscribe(subscription);
                    break;

                case SubscriptionState::Pending:
                case SubscriptionState::Error:
                case SubscriptionState::Complete:
                    break;

                case SubscriptionState::Invalidated:
                    partial_sync_done = true;
                    break;
            }
        });
        EventLoop::main().run_until([&] { return partial_sync_done; });
    }

    SECTION("unnamed query can be unsubscribed while in pending state") {
        auto subscription = subscription_with_query("number > 1", partial_config, "object_a", util::none);

        bool partial_sync_done = false;
        auto token = subscription.add_notification_callback([&] {
            using SubscriptionState = partial_sync::SubscriptionState;

            switch (subscription.state()) {
                case SubscriptionState::Pending:
                    partial_sync::unsubscribe(subscription);
                    break;

                case SubscriptionState::Creating:
                case SubscriptionState::Error:
                case SubscriptionState::Complete:
                    break;

                case SubscriptionState::Invalidated:
                    partial_sync_done = true;
                    break;
            }
        });
        EventLoop::main().run_until([&] { return partial_sync_done; });
    }

    SECTION("unnamed query can be unsubscribed while in complete state") {
        auto subscription = subscription_with_query("number > 1", partial_config, "object_a", util::none);

        bool partial_sync_done = false;
        auto token = subscription.add_notification_callback([&] {
            using SubscriptionState = partial_sync::SubscriptionState;

            switch (subscription.state()) {
                case SubscriptionState::Complete:
                    partial_sync::unsubscribe(subscription);
                    break;

                case SubscriptionState::Creating:
                case SubscriptionState::Pending:
                case SubscriptionState::Error:
                    break;

                case SubscriptionState::Invalidated:
                    partial_sync_done = true;
                    break;
            }
        });
        EventLoop::main().run_until([&] { return partial_sync_done; });
    }

    SECTION("unnamed query can be unsubscribed while in invalidated state") {
        auto subscription = subscription_with_query("number > 1", partial_config, "object_a", util::none);
        partial_sync::unsubscribe(subscription);

        bool partial_sync_done = false;
        auto token = subscription.add_notification_callback([&] {
            using SubscriptionState = partial_sync::SubscriptionState;

            switch (subscription.state()) {
                case SubscriptionState::Creating:
                case SubscriptionState::Pending:
                case SubscriptionState::Complete:
                case SubscriptionState::Error:
                    break;

                case SubscriptionState::Invalidated:
                    // We're only testing that this doesn't blow up since it should have no effect.
                    partial_sync::unsubscribe(subscription);
                    partial_sync_done = true;
                    break;
            }
        });
        EventLoop::main().run_until([&] { return partial_sync_done; });
    }

    SECTION("unnamed query can be unsubscribed while in error state") {
        auto subscription_1 = subscription_with_query("number != 1", partial_config, "object_a", "query"s);
        auto subscription_2 = subscription_with_query("number > 1", partial_config, "object_a", "query"s);

        bool partial_sync_done = false;
        auto token = subscription_2.add_notification_callback([&] {
            using SubscriptionState = partial_sync::SubscriptionState;

            switch (subscription_2.state()) {
                case SubscriptionState::Error:
                    partial_sync::unsubscribe(subscription_2);
                    break;

                case SubscriptionState::Creating:
                case SubscriptionState::Pending:
                case SubscriptionState::Complete:
                    break;

                case SubscriptionState::Invalidated:
                    partial_sync_done = true;
                    break;
            }
        });
        EventLoop::main().run_until([&] { return partial_sync_done; });
    }

    SECTION("clearing a `Results` backed by a table works with partial sync") {
        // The `ClearTable` instruction emitted by `Table::clear` won't be supported on partially-synced Realms
        // going forwards. Currently it gives incorrect results. Verify that `Results::clear` backed by a table
        // uses something other than `Table::clear` and gives the results we expect.

        // Subscribe to a subset of `object_a` objects.
        auto subscription = subscribe_and_wait("number > 1", partial_config, "object_a", util::none, [&](Results results, std::exception_ptr error) {
            REQUIRE(!error);
            REQUIRE(results.size() == 2);

            // Remove all objects that matched our subscription.
            auto realm = results.get_realm();
            auto table = ObjectStore::table_for_object_type(realm->read_group(), "object_a");
            realm->begin_transaction();
            Results(realm, *table).clear();
            realm->commit_transaction();

            std::atomic<bool> upload_done(false);
            auto session = SyncManager::shared().get_existing_active_session(partial_config.path);
            session->wait_for_upload_completion([&](auto) { upload_done = true; });
            EventLoop::main().run_until([&] { return upload_done.load(); });
        });
        partial_sync::unsubscribe(subscription);

        // Ensure that all objects that matched our subscription above were removed, and that
        // the non-matching objects remain.
        subscribe_and_wait("TRUEPREDICATE", partial_config, "object_a", util::none, [](Results results, std::exception_ptr error) {
            REQUIRE(!error);
            REQUIRE(results.size() == 1);
        });
    }

    SECTION("works with Realm opened using `asyncOpen`") {
        // Perform an asynchronous open like bindings do by first opening the Realm without any schema,
        // waiting for the initial download to complete, and then re-opening the Realm with the correct schema.
        {
            Realm::Config async_partial_config(partial_config);
            async_partial_config.schema = {};
            async_partial_config.cache = false;

            auto async_realm = Realm::get_shared_realm(async_partial_config);
            std::atomic<bool> download_done(false);
            auto session = SyncManager::shared().get_existing_active_session(partial_config.path);
            session->wait_for_download_completion([&](auto) {
                download_done = true;
            });
            EventLoop::main().run_until([&] { return download_done.load(); });
        }

        subscribe_and_wait("string = \"partial\"", partial_config, "object_a", util::none, [](Results results, std::exception_ptr) {
            REQUIRE(results.size() == 2);
            REQUIRE(results_contains(results, {1, 10, "partial"}));
            REQUIRE(results_contains(results, {2, 2, "partial"}));
        });
    }
}

TEST_CASE("Partial sync error checking", "[sync]") {
    SyncManager::shared().configure_file_system(tmp_dir(), SyncManager::MetadataMode::NoEncryption);

    SECTION("API misuse throws an exception from `subscribe`") {
        SECTION("non-synced Realm") {
            TestFile config;
            config.schema = partial_sync_schema();
            auto realm = Realm::get_shared_realm(config);
            auto table = ObjectStore::table_for_object_type(realm->read_group(), "object_a");
            CHECK_THROWS(subscribe_and_wait(Results(realm, *table), util::none, [](Results, std::exception_ptr) { }));
        }

        SECTION("synced, non-partial Realm") {
            SyncServer server;
            SyncTestFile config(server, "test");
            config.schema = partial_sync_schema();
            auto realm = Realm::get_shared_realm(config);
            auto table = ObjectStore::table_for_object_type(realm->read_group(), "object_a");
            CHECK_THROWS(subscribe_and_wait(Results(realm, *table), util::none, [](Results, std::exception_ptr) { }));
        }
    }

    SECTION("subscription error handling") {
        SyncServer server;
        SyncTestFile config(server, "test");
        config.schema = partial_sync_schema();
        SyncTestFile partial_config(server, "test", true);
        partial_config.schema = partial_sync_schema();
        // Add some objects for test purposes.
        populate_realm(config,
            {{1, 10, "partial"}, {2, 2, "partial"}, {3, 8, "sync"}},
            {{3, "meela", "orange"}, {4, "jyaku", "kiwi"}, {5, "meela", "cherry"}, {6, "meela", "kiwi"}, {7, "jyaku", "orange"}}
            );

        SECTION("reusing the same name for different queries should raise an error") {
            subscribe_and_wait("number > 0", partial_config, "object_a", "query"s, [](Results results, std::exception_ptr error) {
                REQUIRE(!error);
                REQUIRE(results.size() == 3);
            });

            subscribe_and_wait("number <= 0", partial_config, "object_a", "query"s, [](Results, std::exception_ptr error) {
                REQUIRE(error);
            });
        }

        SECTION("reusing the same name for identical queries on different types should raise an error") {
            subscribe_and_wait("number > 0", partial_config, "object_a", "query"s, [](Results results, std::exception_ptr error) {
                REQUIRE(!error);
                REQUIRE(results.size() == 3);
            });

            subscribe_and_wait("number > 0", partial_config, "object_b", "query"s, [](Results, std::exception_ptr error) {
                REQUIRE(error);
            });
        }

        SECTION("unsupported queries should raise an error") {
            // To test handling of invalid queries, we rely on the fact that core does not yet support `links_to`
            // queries as it cannot serialize an object reference until we have stable ID support.

            // Ensure that the placeholder object in `link_target` is available.
            subscribe_and_wait("TRUEPREDICATE", partial_config, "link_target", util::none, [](Results results, std::exception_ptr error) {
                REQUIRE(!error);
                REQUIRE(results.size() == 1);
            });

            auto r = Realm::get_shared_realm(partial_config);
            const auto& object_schema = r->schema().find("object_a");
            auto source_table = ObjectStore::table_for_object_type(r->read_group(), "object_a");
            auto target_table = ObjectStore::table_for_object_type(r->read_group(), "link_target");

            // Attempt to subscribe to a `links_to` query.
            Query q = source_table->where().links_to(object_schema->property_for_name("link")->table_column,
                                                     target_table->get(0));
            CHECK_THROWS(partial_sync::subscribe(Results(r, q), util::none));
        }
    }
}
