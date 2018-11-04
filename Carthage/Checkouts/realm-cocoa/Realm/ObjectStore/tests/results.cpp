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
#include "util/index_helpers.hpp"
#include "util/templated_test_case.hpp"
#include "util/test_file.hpp"

#include "impl/object_accessor_impl.hpp"
#include "impl/realm_coordinator.hpp"
#include "binding_context.hpp"
#include "object_schema.hpp"
#include "property.hpp"
#include "results.hpp"
#include "schema.hpp"

#include <realm/group_shared.hpp>
#include <realm/link_view.hpp>
#include <realm/query_engine.hpp>
#include <realm/query_expression.hpp>

#if REALM_ENABLE_SYNC
#include "sync/sync_manager.hpp"
#include "sync/sync_session.hpp"
#endif


using namespace realm;
using namespace std::string_literals;

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

    void will_change(Object const&, Property const&) {}
    void did_change() {}
    std::string print(util::Any) { return "not implemented"; }
    bool allow_missing(util::Any) { return false; }
};


TEST_CASE("notifications: async delivery") {
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

    r->begin_transaction();
    table->add_empty_row(10);
    for (int i = 0; i < 10; ++i)
        table->set_int(0, i, i * 2);
    r->commit_transaction();

    Results results(r, table->where().greater(0, 0).less(0, 10));

    int notification_calls = 0;
    auto token = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
        REQUIRE_FALSE(err);
        ++notification_calls;
    });

    auto make_local_change = [&] {
        r->begin_transaction();
        table->set_int(0, 0, 4);
        r->commit_transaction();
    };

    auto make_remote_change = [&] {
        auto r2 = coordinator->get_realm();
        r2->begin_transaction();
        r2->read_group().get_table("class_object")->set_int(0, 0, 5);
        r2->commit_transaction();
    };

    SECTION("initial notification") {
        SECTION("is delivered on notify()") {
            REQUIRE(notification_calls == 0);
            advance_and_notify(*r);
            REQUIRE(notification_calls == 1);
        }

        SECTION("is delivered on refresh()") {
            coordinator->on_change();
            REQUIRE(notification_calls == 0);
            r->refresh();
            REQUIRE(notification_calls == 1);
        }

        SECTION("is delivered on begin_transaction()") {
            coordinator->on_change();
            REQUIRE(notification_calls == 0);
            r->begin_transaction();
            REQUIRE(notification_calls == 1);
            r->cancel_transaction();
        }

        SECTION("is delivered on notify() even with autorefresh disabled") {
            r->set_auto_refresh(false);
            REQUIRE(notification_calls == 0);
            advance_and_notify(*r);
            REQUIRE(notification_calls == 1);
        }

        SECTION("refresh() blocks due to initial results not being ready") {
            REQUIRE(notification_calls == 0);
            JoiningThread thread([&] {
                std::this_thread::sleep_for(std::chrono::microseconds(5000));
                coordinator->on_change();
            });
            r->refresh();
            REQUIRE(notification_calls == 1);
        }

        SECTION("begin_transaction() blocks due to initial results not being ready") {
            REQUIRE(notification_calls == 0);
            JoiningThread thread([&] {
                std::this_thread::sleep_for(std::chrono::microseconds(5000));
                coordinator->on_change();
            });
            r->begin_transaction();
            REQUIRE(notification_calls == 1);
            r->cancel_transaction();
        }

        SECTION("notify() does not block due to initial results not being ready") {
            REQUIRE(notification_calls == 0);
            r->notify();
            REQUIRE(notification_calls == 0);
        }

        SECTION("is delivered after invalidate()") {
            r->invalidate();

            SECTION("notify()") {
                coordinator->on_change();
                REQUIRE_FALSE(r->is_in_read_transaction());
                r->notify();
                REQUIRE(notification_calls == 1);
            }

            SECTION("notify() without autorefresh") {
                r->set_auto_refresh(false);
                coordinator->on_change();
                REQUIRE_FALSE(r->is_in_read_transaction());
                r->notify();
                REQUIRE(notification_calls == 1);
            }

            SECTION("refresh()") {
                coordinator->on_change();
                REQUIRE_FALSE(r->is_in_read_transaction());
                r->refresh();
                REQUIRE(notification_calls == 1);
            }

            SECTION("begin_transaction()") {
                coordinator->on_change();
                REQUIRE_FALSE(r->is_in_read_transaction());
                r->begin_transaction();
                REQUIRE(notification_calls == 1);
                r->cancel_transaction();
            }
        }

        SECTION("is delivered by notify() even if there are later versions") {
            REQUIRE(notification_calls == 0);
            coordinator->on_change();
            make_remote_change();
            r->notify();
            REQUIRE(notification_calls == 1);
        }
    }

    advance_and_notify(*r);

    SECTION("notifications for local changes") {
        make_local_change();
        coordinator->on_change();
        REQUIRE(notification_calls == 1);

        SECTION("notify()") {
            r->notify();
            REQUIRE(notification_calls == 2);
        }

        SECTION("notify() without autorefresh") {
            r->set_auto_refresh(false);
            r->notify();
            REQUIRE(notification_calls == 2);
        }

        SECTION("refresh()") {
            r->refresh();
            REQUIRE(notification_calls == 2);
        }

        SECTION("begin_transaction()") {
            r->begin_transaction();
            REQUIRE(notification_calls == 2);
            r->cancel_transaction();
        }
    }

    SECTION("notifications for remote changes") {
        make_remote_change();
        coordinator->on_change();
        REQUIRE(notification_calls == 1);

        SECTION("notify()") {
            r->notify();
            REQUIRE(notification_calls == 2);
        }

        SECTION("notify() without autorefresh") {
            r->set_auto_refresh(false);
            r->notify();
            REQUIRE(notification_calls == 1);
            r->refresh();
            REQUIRE(notification_calls == 2);
        }

        SECTION("refresh()") {
            r->refresh();
            REQUIRE(notification_calls == 2);
        }

        SECTION("begin_transaction()") {
            r->begin_transaction();
            REQUIRE(notification_calls == 2);
            r->cancel_transaction();
        }
    }

    SECTION("notifications are not delivered when the token is destroyed before they are calculated") {
        make_remote_change();
        REQUIRE(notification_calls == 1);
        token = {};
        advance_and_notify(*r);
        REQUIRE(notification_calls == 1);
    }

    SECTION("notifications are not delivered when the token is destroyed before they are delivered") {
        make_remote_change();
        REQUIRE(notification_calls == 1);
        coordinator->on_change();
        token = {};
        r->notify();
        REQUIRE(notification_calls == 1);
    }

    SECTION("notifications are delivered on the next cycle when a new callback is added from within a callback") {
        NotificationToken token2, token3;
        bool called = false;
        token2 = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
            token2 = {};
            token3 = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
                called = true;
            });
        });

        advance_and_notify(*r);
        REQUIRE_FALSE(called);
        advance_and_notify(*r);
        REQUIRE(called);
    }

    SECTION("notifications are delivered on the next cycle when a new callback is added from within a callback") {
        auto results2 = results;
        auto results3 = results;
        NotificationToken token2, token3, token4;

        bool called = false;
        auto check = [&](Results& outer, Results& inner) {
            token2 = outer.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
                token2 = {};
                token3 = inner.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
                    called = true;
                });
            });

            advance_and_notify(*r);
            REQUIRE_FALSE(called);
            advance_and_notify(*r);
            REQUIRE(called);
        };

        SECTION("same Results") {
            check(results, results);
        }

        SECTION("Results which has never had a notifier") {
            check(results, results2);
        }

        SECTION("Results which used to have callbacks but no longer does") {
            SECTION("notifier before active") {
                token3 = results2.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
                    token3 = {};
                });
                check(results3, results2);
            }
            SECTION("notifier after active") {
                token3 = results2.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
                    token3 = {};
                });
                check(results, results2);
            }
        }

        SECTION("Results which already has callbacks") {
            SECTION("notifier before active") {
                token4 = results2.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) { });
                check(results3, results2);
            }
            SECTION("notifier after active") {
                token4 = results2.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) { });
                check(results, results2);
            }
        }
    }

    SECTION("remote changes made before adding a callback from within a callback are not reported") {
        NotificationToken token2, token3;
        bool called = false;
        token2 = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
            token2 = {};
            make_remote_change();
            coordinator->on_change();
            token3 = results.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                called = true;
                REQUIRE(c.empty());
                REQUIRE(table->get_int(0, 0) == 5);
            });
        });

        advance_and_notify(*r);
        REQUIRE_FALSE(called);
        advance_and_notify(*r);
        REQUIRE(called);
    }

    SECTION("notifications are not delivered when a callback is removed from within a callback") {
        NotificationToken token2, token3;
        token2 = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
            token3 = {};
        });
        token3 = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
            REQUIRE(false);
        });

        advance_and_notify(*r);
    }

    SECTION("removing the current callback does not stop later ones from being called") {
        NotificationToken token2, token3;
        bool called = false;
        token2 = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
            token2 = {};
        });
        token3 = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
            called = true;
        });

        advance_and_notify(*r);

        REQUIRE(called);
    }

    SECTION("the first call of a notification can include changes if it previously ran for a different callback") {
        r->begin_transaction();
        auto token2 = results.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
            REQUIRE(!c.empty());
        });

        table->set_int(0, table->add_empty_row(), 5);
        r->commit_transaction();
        advance_and_notify(*r);
    }

    SECTION("handling of results not ready") {
        make_remote_change();

        SECTION("notify() does nothing") {
            r->notify();
            REQUIRE(notification_calls == 1);
            coordinator->on_change();
            r->notify();
            REQUIRE(notification_calls == 2);
        }

        SECTION("refresh() blocks") {
            REQUIRE(notification_calls == 1);
            JoiningThread thread([&] {
                std::this_thread::sleep_for(std::chrono::microseconds(5000));
                coordinator->on_change();
            });
            r->refresh();
            REQUIRE(notification_calls == 2);
        }

        SECTION("refresh() advances to the first version with notifiers ready that is at least a recent as the newest at the time it is called") {
            JoiningThread thread([&] {
                std::this_thread::sleep_for(std::chrono::microseconds(5000));
                make_remote_change();
                coordinator->on_change();
                make_remote_change();
            });
            // advances to the version after the one it was waiting for, but still
            // not the latest
            r->refresh();
            REQUIRE(notification_calls == 2);

            thread.join();
            REQUIRE(notification_calls == 2);

            // now advances to the latest
            coordinator->on_change();
            r->refresh();
            REQUIRE(notification_calls == 3);
        }

        SECTION("begin_transaction() blocks") {
            REQUIRE(notification_calls == 1);
            JoiningThread thread([&] {
                std::this_thread::sleep_for(std::chrono::microseconds(5000));
                coordinator->on_change();
            });
            r->begin_transaction();
            REQUIRE(notification_calls == 2);
            r->cancel_transaction();
        }

        SECTION("refresh() does not block for results without callbacks") {
            token = {};
            // this would deadlock if it waits for the notifier to be ready
            r->refresh();
        }

        SECTION("begin_transaction() does not block for results without callbacks") {
            token = {};
            // this would deadlock if it waits for the notifier to be ready
            r->begin_transaction();
            r->cancel_transaction();
        }

        SECTION("begin_transaction() does not block for Results for different Realms") {
            // this would deadlock if beginning the write on the secondary Realm
            // waited for the primary Realm to be ready
            make_remote_change();

            // sanity check that the notifications never did run
            r->notify();
            REQUIRE(notification_calls == 1);
        }
    }

    SECTION("handling of stale results") {
        make_remote_change();
        coordinator->on_change();
        make_remote_change();

        SECTION("notify() uses the older version") {
            r->notify();
            REQUIRE(notification_calls == 2);
            coordinator->on_change();
            r->notify();
            REQUIRE(notification_calls == 3);
            r->notify();
            REQUIRE(notification_calls == 3);
        }

        SECTION("refresh() blocks") {
            REQUIRE(notification_calls == 1);
            JoiningThread thread([&] {
                std::this_thread::sleep_for(std::chrono::microseconds(5000));
                coordinator->on_change();
            });
            r->refresh();
            REQUIRE(notification_calls == 2);
        }

        SECTION("begin_transaction() blocks") {
            REQUIRE(notification_calls == 1);
            JoiningThread thread([&] {
                std::this_thread::sleep_for(std::chrono::microseconds(5000));
                coordinator->on_change();
            });
            r->begin_transaction();
            REQUIRE(notification_calls == 2);
            r->cancel_transaction();
        }
    }

    SECTION("updates are delivered after invalidate()") {
        r->invalidate();
        make_remote_change();

        SECTION("notify()") {
            coordinator->on_change();
            REQUIRE_FALSE(r->is_in_read_transaction());
            r->notify();
            REQUIRE(notification_calls == 2);
        }

        SECTION("notify() without autorefresh") {
            r->set_auto_refresh(false);
            coordinator->on_change();
            REQUIRE_FALSE(r->is_in_read_transaction());
            r->notify();
            REQUIRE(notification_calls == 1);
            r->refresh();
            REQUIRE(notification_calls == 2);
        }

        SECTION("refresh()") {
            coordinator->on_change();
            REQUIRE_FALSE(r->is_in_read_transaction());
            r->refresh();
            REQUIRE(notification_calls == 2);
        }

        SECTION("begin_transaction()") {
            coordinator->on_change();
            REQUIRE_FALSE(r->is_in_read_transaction());
            r->begin_transaction();
            REQUIRE(notification_calls == 2);
            r->cancel_transaction();
        }
    }

    SECTION("refresh() from within changes_available() do not interfere with notification delivery") {
        struct Context : BindingContext {
            Realm& realm;
            Context(Realm& realm) : realm(realm) { }

            void changes_available() override
            {
                REQUIRE(realm.refresh());
            }
        };

        make_remote_change();
        coordinator->on_change();

        r->set_auto_refresh(false);
        REQUIRE(notification_calls == 1);

        r->notify();
        REQUIRE(notification_calls == 1);

        r->m_binding_context.reset(new Context(*r));
        r->notify();
        REQUIRE(notification_calls == 2);
    }

    SECTION("refresh() from within a notification is a no-op") {
        token = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            REQUIRE_FALSE(r->refresh()); // would deadlock if it actually tried to refresh
        });
        advance_and_notify(*r);
        make_remote_change(); // 1
        coordinator->on_change();
        make_remote_change(); // 2
        r->notify(); // advances to version from 1
        coordinator->on_change();
        REQUIRE(r->refresh()); // advances to version from 2
        REQUIRE_FALSE(r->refresh()); // does not advance since it's now up-to-date
    }

    SECTION("begin_transaction() from within a notification does not send notifications immediately") {
        bool first = true;
        auto token2 = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            if (first)
                first = false;
            else {
                // would deadlock if it tried to send notifications as they aren't ready yet
                r->begin_transaction();
                r->cancel_transaction();
            }
        });
        advance_and_notify(*r);

        make_remote_change(); // 1
        coordinator->on_change();
        make_remote_change(); // 2
        r->notify(); // advances to version from 1
        REQUIRE(notification_calls == 2);
        coordinator->on_change();
        REQUIRE_FALSE(r->refresh()); // we made the commit locally, so no advancing here
        REQUIRE(notification_calls == 3);
    }

    SECTION("begin_transaction() from within a notification does not break delivering additional notifications") {
        size_t calls = 0;
        token = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            if (++calls == 1)
                return;

            // force the read version to advance by beginning a transaction
            r->begin_transaction();
            r->cancel_transaction();
        });

        auto results2 = results;
        size_t calls2 = 0;
        auto token2 = results2.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            if (++calls2 == 1)
                return;
            REQUIRE_INDICES(c.insertions, 0);
        });
        advance_and_notify(*r);
        REQUIRE(calls == 1);
        REQUIRE(calls2 == 1);

        make_remote_change(); // 1
        coordinator->on_change();
        make_remote_change(); // 2
        r->notify(); // advances to version from 1

        REQUIRE(calls == 2);
        REQUIRE(calls2 == 2);
    }

    SECTION("begin_transaction() from within did_change() does not break delivering collection notification") {
        struct Context : BindingContext {
            Realm& realm;
            Context(Realm& realm) : realm(realm) { }

            void did_change(std::vector<ObserverState> const&, std::vector<void*> const&, bool) override
            {
                if (!realm.is_in_transaction()) {
                    // advances to version from 2 (and recursively calls this, hence the check above)
                    realm.begin_transaction();
                    realm.cancel_transaction();
                }
            }
        };
        r->m_binding_context.reset(new Context(*r));

        make_remote_change(); // 1
        coordinator->on_change();
        make_remote_change(); // 2
        r->notify(); // advances to version from 1
    }

    SECTION("is_in_transaction() is reported correctly within a notification from begin_transaction() and changes can be made") {
        bool first = true;
        token = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            if (first) {
                REQUIRE_FALSE(r->is_in_transaction());
                first = false;
            }
            else {
                REQUIRE(r->is_in_transaction());
                table->set_int(0, 0, 100);
            }
        });
        advance_and_notify(*r);
        make_remote_change();
        coordinator->on_change();
        r->begin_transaction();
        REQUIRE(table->get_int(0, 0) == 100);
        r->cancel_transaction();
        REQUIRE(table->get_int(0, 0) != 100);
    }

    SECTION("invalidate() from within notification is a no-op") {
        token = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            r->invalidate();
            REQUIRE(r->is_in_read_transaction());
        });
        advance_and_notify(*r);
        REQUIRE(r->is_in_read_transaction());
        make_remote_change();
        coordinator->on_change();
        r->begin_transaction();
        REQUIRE(r->is_in_transaction());
        r->cancel_transaction();
    }

    SECTION("cancel_transaction() from within notification ends the write transaction started by begin_transaction()") {
        token = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            if (r->is_in_transaction())
                r->cancel_transaction();
        });
        advance_and_notify(*r);
        make_remote_change();
        coordinator->on_change();
        r->begin_transaction();
        REQUIRE_FALSE(r->is_in_transaction());
    }
}

TEST_CASE("notifications: skip") {
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

    r->begin_transaction();
    table->add_empty_row(10);
    for (int i = 0; i < 10; ++i)
        table->set_int(0, i, i * 2);
    r->commit_transaction();

    Results results(r, table->where());

    auto add_callback = [](Results& results, int& calls, CollectionChangeSet& changes) {
        return results.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            ++calls;
            changes = std::move(c);
        });
    };

    auto make_local_change = [&](auto& token) {
        r->begin_transaction();
        table->add_empty_row();
        token.suppress_next();
        r->commit_transaction();
    };

    auto make_remote_change = [&] {
        auto r2 = coordinator->get_realm();
        r2->begin_transaction();
        r2->read_group().get_table("class_object")->add_empty_row();
        r2->commit_transaction();
    };

    int calls1 = 0;
    CollectionChangeSet changes1;
    auto token1 = add_callback(results, calls1, changes1);

    SECTION("no notification is sent when only callback is skipped") {
        advance_and_notify(*r);
        REQUIRE(calls1 == 1);

        make_local_change(token1);
        advance_and_notify(*r);

        REQUIRE(calls1 == 1);
        REQUIRE(changes1.empty());
    }

    SECTION("unskipped tokens for the same Results are still delivered") {
        int calls2 = 0;
        CollectionChangeSet changes2;
        auto token2 = add_callback(results, calls2, changes2);

        advance_and_notify(*r);
        REQUIRE(calls1 == 1);
        REQUIRE(calls2 == 1);

        make_local_change(token1);
        advance_and_notify(*r);

        REQUIRE(calls1 == 1);
        REQUIRE(changes1.empty());
        REQUIRE(calls2 == 2);
        REQUIRE_INDICES(changes2.insertions, 10);
    }

    SECTION("unskipped tokens for different Results are still delivered") {
        Results results2(r, table->where());
        int calls2 = 0;
        CollectionChangeSet changes2;
        auto token2 = add_callback(results2, calls2, changes2);

        advance_and_notify(*r);
        REQUIRE(calls1 == 1);
        REQUIRE(calls2 == 1);

        make_local_change(token1);
        advance_and_notify(*r);

        REQUIRE(calls1 == 1);
        REQUIRE(changes1.empty());
        REQUIRE(calls2 == 2);
        REQUIRE_INDICES(changes2.insertions, 10);
    }

    SECTION("additional commits which occur before calculation are merged in") {
        int calls2 = 0;
        CollectionChangeSet changes2;
        auto token2 = add_callback(results, calls2, changes2);

        advance_and_notify(*r);
        REQUIRE(calls1 == 1);
        REQUIRE(calls2 == 1);

        make_local_change(token1);
        make_remote_change();
        advance_and_notify(*r);

        REQUIRE(calls1 == 2);
        REQUIRE_INDICES(changes1.insertions, 11);
        REQUIRE(calls2 == 2);
        REQUIRE_INDICES(changes2.insertions, 10, 11);
    }

    SECTION("additional commits which occur before delivery are merged in") {
        int calls2 = 0;
        CollectionChangeSet changes2;
        auto token2 = add_callback(results, calls2, changes2);

        advance_and_notify(*r);
        REQUIRE(calls1 == 1);
        REQUIRE(calls2 == 1);

        make_local_change(token1);
        coordinator->on_change();
        make_remote_change();
        advance_and_notify(*r);

        REQUIRE(calls1 == 2);
        REQUIRE_INDICES(changes1.insertions, 11);
        REQUIRE(calls2 == 2);
        REQUIRE_INDICES(changes2.insertions, 10, 11);
    }

    SECTION("skipping must be done from within a write transaction") {
        REQUIRE_THROWS(token1.suppress_next());
    }

    SECTION("skipping must be done from the Realm's thread") {
        advance_and_notify(*r);
        r->begin_transaction();
        std::thread([&] {
            REQUIRE_THROWS(token1.suppress_next());
        }).join();
        r->cancel_transaction();
    }

    SECTION("new notifiers do not interfere with skipping") {
        advance_and_notify(*r);
        REQUIRE(calls1 == 1);

        CollectionChangeSet changes;

        // new notifier at a version before the skipped one
        auto r2 = coordinator->get_realm();
        Results results2(r2, r2->read_group().get_table("class_object")->where());
        int calls2 = 0;
        auto token2 = add_callback(results2, calls2, changes);

        make_local_change(token1);

        // new notifier at the skipped version
        auto r3 = coordinator->get_realm();
        Results results3(r3, r3->read_group().get_table("class_object")->where());
        int calls3 = 0;
        auto token3 = add_callback(results3, calls3, changes);

        make_remote_change();

        // new notifier at version after the skipped one
        auto r4 = coordinator->get_realm();
        Results results4(r4, r4->read_group().get_table("class_object")->where());
        int calls4 = 0;
        auto token4 = add_callback(results4, calls4, changes);

        coordinator->on_change();
        r->notify();
        r2->notify();
        r3->notify();
        r4->notify();

        REQUIRE(calls1 == 2);
        REQUIRE(calls2 == 1);
        REQUIRE(calls3 == 1);
        REQUIRE(calls4 == 1);
    }

    SECTION("skipping only effects the current transaction even if no notification would occur anyway") {
        advance_and_notify(*r);
        REQUIRE(calls1 == 1);

        // would not produce a notification even if it wasn't skipped because no changes were made
        r->begin_transaction();
        token1.suppress_next();
        r->commit_transaction();
        advance_and_notify(*r);
        REQUIRE(calls1 == 1);

        // should now produce a notification
        r->begin_transaction();
        table->add_empty_row();
        r->commit_transaction();
        advance_and_notify(*r);
        REQUIRE(calls1 == 2);
    }

    SECTION("removing skipped notifier before it gets the chance to run") {
        advance_and_notify(*r);
        REQUIRE(calls1 == 1);

        // Set the skip version
        make_local_change(token1);
        // Advance the file to a version after the skip version
        make_remote_change();
        REQUIRE(calls1 == 1);

        // Remove the skipped notifier and add an entirely new notifier, so that
        // notifications need to run but the skip logic shouldn't be used
        token1 = {};
        results = {};
        Results results2(r, table->where());
        auto token2 = add_callback(results2, calls1, changes1);

        advance_and_notify(*r);
        REQUIRE(calls1 == 2);
    }
}

#if REALM_PLATFORM_APPLE
TEST_CASE("notifications: async error handling") {
    _impl::RealmCoordinator::assert_no_open_realms();

    InMemoryTestFile config;
    config.cache = false;
    config.automatic_change_notifications = false;

    auto r = Realm::get_shared_realm(config);
    r->update_schema({
        {"object", {
            {"value", PropertyType::Int},
        }},
    });

    auto coordinator = _impl::RealmCoordinator::get_existing_coordinator(config.path);
    Results results(r, *r->read_group().get_table("class_object"));

    auto r2 = Realm::get_shared_realm(config);

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

    SECTION("error when opening the advancer SG") {
        OpenFileLimiter limiter;

        bool called = false;
        auto token = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
            REQUIRE(err);
            REQUIRE_FALSE(called);
            called = true;
        });
        REQUIRE(!called);

        SECTION("error is delivered on notify() without changes") {
            coordinator->on_change();
            REQUIRE(!called);
            r->notify();
            REQUIRE(called);
        }

        SECTION("error is delivered on notify() with changes") {
            r2->begin_transaction(); r2->commit_transaction();
            REQUIRE(!called);
            coordinator->on_change();
            REQUIRE(!called);
            r->notify();
            REQUIRE(called);
        }

        SECTION("error is delivered on refresh() without changes") {
            coordinator->on_change();
            REQUIRE(!called);
            r->refresh();
            REQUIRE(called);
        }

        SECTION("error is delivered on refresh() with changes") {
            r2->begin_transaction(); r2->commit_transaction();
            REQUIRE(!called);
            coordinator->on_change();
            REQUIRE(!called);
            r->refresh();
            REQUIRE(called);
        }

        SECTION("error is delivered on begin_transaction() without changes") {
            coordinator->on_change();
            REQUIRE(!called);
            r->begin_transaction();
            REQUIRE(called);
            r->cancel_transaction();
        }

        SECTION("error is delivered on begin_transaction() with changes") {
            r2->begin_transaction(); r2->commit_transaction();
            REQUIRE(!called);
            coordinator->on_change();
            REQUIRE(!called);
            r->begin_transaction();
            REQUIRE(called);
            r->cancel_transaction();
        }

        SECTION("adding another callback sends the error to only the newly added one") {
            advance_and_notify(*r);
            REQUIRE(called);

            bool called2 = false;
            auto token2 = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
                REQUIRE(err);
                REQUIRE_FALSE(called2);
                called2 = true;
            });

            advance_and_notify(*r);
            REQUIRE(called2);
        }

        SECTION("destroying a token from before the error does not remove newly added callbacks") {
            advance_and_notify(*r);

            bool called = false;
            auto token2 = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
                REQUIRE(err);
                REQUIRE_FALSE(called);
                called = true;
            });
            token = {};

            advance_and_notify(*r);
            REQUIRE(called);
        }

        SECTION("adding another callback from within an error callback defers delivery") {
            NotificationToken token2;
            token = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
                token2 = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
                    REQUIRE(err);
                    REQUIRE_FALSE(called);
                    called = true;
                });
            });
            advance_and_notify(*r);
            REQUIRE(!called);
            advance_and_notify(*r);
            REQUIRE(called);
        }

        SECTION("adding a callback to a different collection from within the error callback defers delivery") {
            auto results2 = results;
            NotificationToken token2;
            token = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) {
                token2 = results2.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
                    REQUIRE(err);
                    REQUIRE_FALSE(called);
                    called = true;
                });
            });
            advance_and_notify(*r);
            REQUIRE(!called);
            advance_and_notify(*r);
            REQUIRE(called);
        }
    }

    SECTION("error when opening the executor SG") {
        SECTION("error is delivered asynchronously") {
            bool called = false;
            auto token = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
                REQUIRE(err);
                called = true;
            });
            OpenFileLimiter limiter;

            REQUIRE(!called);
            coordinator->on_change();
            REQUIRE(!called);
            r->notify();
            REQUIRE(called);
        }

        SECTION("adding another callback only sends the error to the new one") {
            bool called = false;
            auto token = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
                REQUIRE(err);
                REQUIRE_FALSE(called);
                called = true;
            });
            OpenFileLimiter limiter;

            advance_and_notify(*r);

            bool called2 = false;
            auto token2 = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
                REQUIRE(err);
                REQUIRE_FALSE(called2);
                called2 = true;
            });

            advance_and_notify(*r);

            REQUIRE(called2);
        }
    }
}
#endif

#if REALM_ENABLE_SYNC
TEST_CASE("notifications: sync") {
    _impl::RealmCoordinator::assert_no_open_realms();

    SyncServer server(false);
    SyncTestFile config(server);
    config.cache = false;
    config.schema = Schema{
        {"object", {
            {"value", PropertyType::Int},
        }},
    };

    SECTION("sync progress commits do not distrupt notifications") {
        auto r = Realm::get_shared_realm(config);
        auto wait_realm = Realm::get_shared_realm(config);

        Results results(r, *r->read_group().get_table("class_object"));
        Results wait_results(wait_realm, *wait_realm->read_group().get_table("class_object"));
        auto token1 = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) { });
        auto token2 = wait_results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr) { });

        // Add an object to the Realm so that notifications are needed
        {
            auto write_realm = Realm::get_shared_realm(config);
            write_realm->begin_transaction();
            sync::create_object(write_realm->read_group(), *write_realm->read_group().get_table("class_object"));
            write_realm->commit_transaction();
        }

        // Wait for the notifications to become ready for the new version
        wait_realm->refresh();

        // Start the server and wait for the Realm to be uploaded so that sync
        // makes some writes to the Realm and bumps the version
        server.start();
        wait_for_upload(*r);

        // Make sure that the notifications still get delivered rather than
        // waiting forever due to that we don't get a commit notification from
        // the commits sync makes to store the upload progress
        r->refresh();
    }
}
#endif

TEST_CASE("notifications: results") {
    _impl::RealmCoordinator::assert_no_open_realms();

    InMemoryTestFile config;
    config.cache = false;
    config.automatic_change_notifications = false;

    auto r = Realm::get_shared_realm(config);
    r->update_schema({
        {"object", {
            {"value", PropertyType::Int},
            {"link", PropertyType::Object|PropertyType::Nullable, "linked to object"}
        }},
        {"other object", {
            {"value", PropertyType::Int}
        }},
        {"linking object", {
            {"link", PropertyType::Object|PropertyType::Nullable, "object"}
        }},
        {"linked to object", {
            {"value", PropertyType::Int}
        }}
    });

    auto coordinator = _impl::RealmCoordinator::get_existing_coordinator(config.path);
    auto table = r->read_group().get_table("class_object");

    r->begin_transaction();
    r->read_group().get_table("class_linked to object")->add_empty_row(10);
    table->add_empty_row(10);
    for (int i = 0; i < 10; ++i) {
        table->set_int(0, i, i * 2);
        table->set_link(1, i, i);
    }
    r->commit_transaction();

    auto r2 = coordinator->get_realm();
    auto r2_table = r2->read_group().get_table("class_object");

    Results results(r, table->where().greater(0, 0).less(0, 10));

    SECTION("unsorted notifications") {
        int notification_calls = 0;
        CollectionChangeSet change;
        auto token = results.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            change = c;
            ++notification_calls;
        });

        advance_and_notify(*r);

        auto write = [&](auto&& f) {
            r->begin_transaction();
            f();
            r->commit_transaction();
            advance_and_notify(*r);
        };

        SECTION("modifications to unrelated tables do not send notifications") {
            write([&] {
                r->read_group().get_table("class_other object")->add_empty_row();
            });
            REQUIRE(notification_calls == 1);
        }

        SECTION("irrelevant modifications to linked tables do not send notifications") {
            write([&] {
                r->read_group().get_table("class_linked to object")->add_empty_row();
            });
            REQUIRE(notification_calls == 1);
        }

        SECTION("irrelevant modifications to linking tables do not send notifications") {
            write([&] {
                r->read_group().get_table("class_linking object")->add_empty_row();
            });
            REQUIRE(notification_calls == 1);
        }

        SECTION("modifications that leave a non-matching row non-matching do not send notifications") {
            write([&] {
                table->set_int(0, 6, 13);
            });
            REQUIRE(notification_calls == 1);
        }

        SECTION("deleting non-matching rows does not send a notification") {
            write([&] {
                table->move_last_over(0);
                table->move_last_over(6);
            });
            REQUIRE(notification_calls == 1);
        }

        SECTION("swapping adjacent matching and non-matching rows does not send notifications") {
            write([&] {
                table->swap_rows(0, 1);
            });
            REQUIRE(notification_calls == 1);
        }

        SECTION("swapping non-adjacent matching and non-matching rows send a single insert/delete pair") {
            write([&] {
                table->swap_rows(0, 2);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.deletions, 1);
            REQUIRE_INDICES(change.insertions, 0);
        }

        SECTION("swapping matching rows sends insert/delete pairs") {
            write([&] {
                table->swap_rows(1, 4);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.deletions, 0, 3);
            REQUIRE_INDICES(change.insertions, 0, 3);

            write([&] {
                table->swap_rows(1, 2);
                table->swap_rows(2, 3);
                table->swap_rows(3, 4);
            });
            REQUIRE(notification_calls == 3);
            REQUIRE_INDICES(change.deletions, 1, 2, 3);
            REQUIRE_INDICES(change.insertions, 0, 1, 2);
        }

        SECTION("swap does not inhibit move collapsing after removals") {
            write([&] {
                table->swap_rows(2, 3);
                table->set_int(0, 3, 100);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.deletions, 1);
            REQUIRE(change.insertions.empty());
        }

        SECTION("modifying a matching row and leaving it matching marks that row as modified") {
            write([&] {
                table->set_int(0, 1, 3);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.modifications, 0);
            REQUIRE_INDICES(change.modifications_new, 0);
        }

        SECTION("modifying a matching row to no longer match marks that row as deleted") {
            write([&] {
                table->set_int(0, 2, 0);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.deletions, 1);
        }

        SECTION("modifying a non-matching row to match marks that row as inserted, but not modified") {
            write([&] {
                table->set_int(0, 7, 3);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.insertions, 4);
            REQUIRE(change.modifications.empty());
            REQUIRE(change.modifications_new.empty());
        }

        SECTION("deleting a matching row marks that row as deleted") {
            write([&] {
                table->move_last_over(3);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.deletions, 2);
        }

        SECTION("moving a matching row via deletion marks that row as moved") {
            write([&] {
                table->where().greater_equal(0, 10).find_all().clear(RemoveMode::unordered);
                table->move_last_over(0);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_MOVES(change, {3, 0});
        }

        SECTION("moving a matching row via subsumption marks that row as modified") {
            write([&] {
                table->where().greater_equal(0, 10).find_all().clear(RemoveMode::unordered);
                table->move_last_over(0);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_MOVES(change, {3, 0});
        }

        SECTION("modifications from multiple transactions are collapsed") {
            r2->begin_transaction();
            r2_table->set_int(0, 0, 6);
            r2->commit_transaction();

            coordinator->on_change();

            r2->begin_transaction();
            r2_table->set_int(0, 1, 0);
            r2->commit_transaction();

            REQUIRE(notification_calls == 1);
            coordinator->on_change();
            r->notify();
            REQUIRE(notification_calls == 2);
        }

        SECTION("inserting a row then modifying it in a second transaction does not report it as modified") {
            r2->begin_transaction();
            size_t ndx = r2_table->add_empty_row();
            r2_table->set_int(0, ndx, 6);
            r2->commit_transaction();

            coordinator->on_change();

            r2->begin_transaction();
            r2_table->set_int(0, ndx, 7);
            r2->commit_transaction();

            advance_and_notify(*r);

            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.insertions, 4);
            REQUIRE(change.modifications.empty());
            REQUIRE(change.modifications_new.empty());
        }

        SECTION("modification indices are pre-insert/delete") {
            r->begin_transaction();
            table->set_int(0, 2, 0);
            table->set_int(0, 3, 6);
            r->commit_transaction();
            advance_and_notify(*r);

            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.deletions, 1);
            REQUIRE_INDICES(change.modifications, 2);
            REQUIRE_INDICES(change.modifications_new, 1);
        }

        SECTION("notifications are not delivered when collapsing transactions results in no net change") {
            r2->begin_transaction();
            size_t ndx = r2_table->add_empty_row();
            r2_table->set_int(0, ndx, 5);
            r2->commit_transaction();

            coordinator->on_change();

            r2->begin_transaction();
            r2_table->move_last_over(ndx);
            r2->commit_transaction();

            REQUIRE(notification_calls == 1);
            coordinator->on_change();
            r->notify();
            REQUIRE(notification_calls == 1);
        }

        SECTION("inserting a non-matching row at the beginning does not produce a notification") {
            write([&] {
                table->insert_empty_row(1);
            });
            REQUIRE(notification_calls == 1);
        }

        SECTION("inserting a matching row at the beginning marks just it as inserted") {
            write([&] {
                table->insert_empty_row(0);
                table->set_int(0, 0, 5);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.insertions, 0);
        }
    }

    SECTION("before/after change callback") {
        struct Callback {
            size_t before_calls = 0;
            size_t after_calls = 0;
            CollectionChangeSet before_change;
            CollectionChangeSet after_change;
            std::function<void(void)> on_before = []{};
            std::function<void(void)> on_after = []{};

            void before(CollectionChangeSet c) {
                before_change = c;
                ++before_calls;
                on_before();
            }
            void after(CollectionChangeSet c) {
                after_change = c;
                ++after_calls;
                on_after();
            }
            void error(std::exception_ptr) {
                FAIL("error() should not be called");
            }
        } callback;
        auto token = results.add_notification_callback(&callback);
        advance_and_notify(*r);

        SECTION("only after() is called for initial results") {
            REQUIRE(callback.before_calls == 0);
            REQUIRE(callback.after_calls == 1);
            REQUIRE(callback.after_change.empty());
        }

        auto write = [&](auto&& func) {
            r2->begin_transaction();
            func(*r2_table);
            r2->commit_transaction();
            advance_and_notify(*r);
        };

        SECTION("both are called after a write") {
            write([&](auto&& t) {
                t.set_int(0, t.add_empty_row(), 5);
            });
            REQUIRE(callback.before_calls == 1);
            REQUIRE(callback.after_calls == 2);
            REQUIRE_INDICES(callback.before_change.insertions, 4);
            REQUIRE_INDICES(callback.after_change.insertions, 4);
        }

        SECTION("deleted objects are usable in before()") {
            callback.on_before = [&] {
                REQUIRE(results.size() == 4);
                REQUIRE_INDICES(callback.before_change.deletions, 0);
                REQUIRE(results.get(0).is_attached());
                REQUIRE(results.get(0).get_int(0) == 2);
            };
            write([&](auto&& t) {
                t.move_last_over(results.get(0).get_index());
            });
            REQUIRE(callback.before_calls == 1);
            REQUIRE(callback.after_calls == 2);
        }

        SECTION("inserted objects are usable in after()") {
            callback.on_after = [&] {
                REQUIRE(results.size() == 5);
                REQUIRE_INDICES(callback.after_change.insertions, 4);
                REQUIRE(results.last()->get_int(0) == 5);
            };
            write([&](auto&& t) {
                t.set_int(0, t.add_empty_row(), 5);
            });
            REQUIRE(callback.before_calls == 1);
            REQUIRE(callback.after_calls == 2);
        }
    }

    SECTION("sorted notifications") {
        // Sort in descending order
        results = results.sort({*table, {{0}}, {false}});

        int notification_calls = 0;
        CollectionChangeSet change;
        auto token = results.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            change = c;
            ++notification_calls;
        });

        advance_and_notify(*r);

        auto write = [&](auto&& f) {
            r->begin_transaction();
            f();
            r->commit_transaction();
            advance_and_notify(*r);
        };

        SECTION("swapping rows does not send notifications") {
            write([&] {
                table->swap_rows(2, 3);
            });
            REQUIRE(notification_calls == 1);
        }

        SECTION("modifications that leave a non-matching row non-matching do not send notifications") {
            write([&] {
                table->set_int(0, 6, 13);
            });
            REQUIRE(notification_calls == 1);
        }

        SECTION("deleting non-matching rows does not send a notification") {
            write([&] {
                table->move_last_over(0);
                table->move_last_over(6);
            });
            REQUIRE(notification_calls == 1);
        }

        SECTION("modifying a matching row and leaving it matching marks that row as modified") {
            write([&] {
                table->set_int(0, 1, 3);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.modifications, 3);
            REQUIRE_INDICES(change.modifications_new, 3);
        }

        SECTION("swapping leaves modified rows marked as modified") {
            write([&] {
                table->set_int(0, 1, 3);
                table->swap_rows(1, 2);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.modifications, 3);
            REQUIRE_INDICES(change.modifications_new, 3);

            write([&] {
                table->swap_rows(3, 1);
                table->set_int(0, 1, 7);
            });
            REQUIRE(notification_calls == 3);
            REQUIRE_INDICES(change.modifications, 1);
            REQUIRE_INDICES(change.modifications_new, 1);
        }

        SECTION("modifying a matching row to no longer match marks that row as deleted") {
            write([&] {
                table->set_int(0, 2, 0);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.deletions, 2);
        }

        SECTION("modifying a non-matching row to match marks that row as inserted") {
            write([&] {
                table->set_int(0, 7, 3);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.insertions, 3);
        }

        SECTION("deleting a matching row marks that row as deleted") {
            write([&] {
                table->move_last_over(3);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.deletions, 1);
        }

        SECTION("moving a matching row via deletion does not send a notification") {
            write([&] {
                table->where().greater_equal(0, 10).find_all().clear(RemoveMode::unordered);
                table->move_last_over(0);
            });
            REQUIRE(notification_calls == 1);
        }

        SECTION("modifying a matching row to change its position sends insert+delete") {
            write([&] {
                table->set_int(0, 2, 9);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.deletions, 2);
            REQUIRE_INDICES(change.insertions, 0);
        }

        SECTION("modifications from multiple transactions are collapsed") {
            r2->begin_transaction();
            r2_table->set_int(0, 0, 5);
            r2->commit_transaction();

            r2->begin_transaction();
            r2_table->set_int(0, 1, 0);
            r2->commit_transaction();

            REQUIRE(notification_calls == 1);
            advance_and_notify(*r);
            REQUIRE(notification_calls == 2);
        }

        SECTION("moving a matching row by deleting all other rows") {
            r->begin_transaction();
            table->clear();
            table->add_empty_row(2);
            table->set_int(0, 0, 15);
            table->set_int(0, 1, 5);
            r->commit_transaction();
            advance_and_notify(*r);

            write([&] {
                table->move_last_over(0);
                table->add_empty_row();
                table->set_int(0, 1, 3);
            });

            REQUIRE(notification_calls == 3);
            REQUIRE(change.deletions.empty());
            REQUIRE_INDICES(change.insertions, 1);
        }
    }

    SECTION("distinct notifications") {
        results = results.distinct(SortDescriptor(*table, {{0}}));

        int notification_calls = 0;
        CollectionChangeSet change;
        auto token = results.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            change = c;
            ++notification_calls;
        });

        advance_and_notify(*r);

        auto write = [&](auto&& f) {
            r->begin_transaction();
            f();
            r->commit_transaction();
            advance_and_notify(*r);
        };

        SECTION("modifications that leave a non-matching row non-matching do not send notifications") {
            write([&] {
                table->set_int(0, 6, 13);
            });
            REQUIRE(notification_calls == 1);
        }

        SECTION("deleting non-matching rows does not send a notification") {
            write([&] {
                table->move_last_over(0);
                table->move_last_over(6);
            });
            REQUIRE(notification_calls == 1);
        }

        SECTION("modifying a matching row and leaving it matching marks that row as modified") {
            write([&] {
                table->set_int(0, 1, 3);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.modifications, 0);
            REQUIRE_INDICES(change.modifications_new, 0);
        }

        SECTION("modifying a non-matching row which is after the distinct results in the table to be a same value \
                in the distinct results doesn't send notification.") {
            write([&] {
                table->set_int(0, 6, 2);
            });
            REQUIRE(notification_calls == 1);
        }

        SECTION("modifying a non-matching row which is before the distinct results in the table to be a same value \
                in the distinct results send insert + delete.") {
            write([&] {
                table->set_int(0, 0, 2);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.deletions, 0);
            REQUIRE_INDICES(change.insertions, 0);
        }

        SECTION("modifying a matching row to duplicated value in distinct results marks that row as deleted") {
            write([&] {
                table->set_int(0, 2, 2);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.deletions, 1);
        }

        SECTION("modifying a non-matching row to match and different value marks that row as inserted") {
            write([&] {
                table->set_int(0, 0, 1);
            });
            REQUIRE(notification_calls == 2);
            REQUIRE_INDICES(change.insertions, 0);
        }
    }

    SECTION("schema changes") {
        CollectionChangeSet change;
        auto token = results.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            change = c;
        });
        advance_and_notify(*r);

        auto write = [&](auto&& f) {
            r->begin_transaction();
            f();
            r->commit_transaction();
            advance_and_notify(*r);
        };

        SECTION("insert table before observed table") {
            write([&] {
                size_t row = table->add_empty_row();
                table->set_int(0, row, 5);
                r->read_group().insert_table(0, "new table");
                table->insert_empty_row(0);
                table->set_int(0, 0, 5);
            });
            REQUIRE_INDICES(change.insertions, 0, 5);
        }

        auto linked_table = table->get_link_target(1);
        SECTION("insert new column before link column") {
            write([&] {
                linked_table->set_int(0, 1, 5);
                table->insert_column(0, type_Int, "new col");
                linked_table->set_int(0, 2, 5);
            });
            REQUIRE_INDICES(change.modifications, 0, 1);
        }

        SECTION("insert table before link target") {
            write([&] {
                linked_table->set_int(0, 1, 5);
                r->read_group().insert_table(0, "new table");
                linked_table->set_int(0, 2, 5);
            });
            REQUIRE_INDICES(change.modifications, 0, 1);
        }
    }
}

TEST_CASE("results: notifications after move") {
    InMemoryTestFile config;
    config.cache = false;
    config.automatic_change_notifications = false;

    auto r = Realm::get_shared_realm(config);
    r->update_schema({
        {"object", {
            {"value", PropertyType::Int},
        }},
    });

    auto table = r->read_group().get_table("class_object");
    auto results = std::make_unique<Results>(r, *table);

    int notification_calls = 0;
    auto token = results->add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
        REQUIRE_FALSE(err);
        ++notification_calls;
    });

    advance_and_notify(*r);

    auto write = [&](auto&& f) {
        r->begin_transaction();
        f();
        r->commit_transaction();
        advance_and_notify(*r);
    };

    SECTION("notifications continue to work after Results is moved (move-constructor)") {
        Results r(std::move(*results));
        results.reset();

        write([&] {
            table->set_int(0, table->add_empty_row(), 1);
        });
        REQUIRE(notification_calls == 2);
    }

    SECTION("notifications continue to work after Results is moved (move-assignment)") {
        Results r;
        r = std::move(*results);
        results.reset();

        write([&] {
            table->set_int(0, table->add_empty_row(), 1);
        });
        REQUIRE(notification_calls == 2);
    }
}

TEST_CASE("results: implicit background notifier") {
    _impl::RealmCoordinator::assert_no_open_realms();

    InMemoryTestFile config;
    config.cache = false;
    config.automatic_change_notifications = false;

    auto coordinator = _impl::RealmCoordinator::get_coordinator(config.path);
    auto r = coordinator->get_realm(std::move(config));
    r->update_schema({
        {"object", {
            {"value", PropertyType::Int},
        }},
    });

    auto table = r->read_group().get_table("class_object");
    Results results(r, table->where());
    results.last(); // force evaluation and creation of TableView

    SECTION("refresh() does not block due to implicit notifier") {
        auto r2 = coordinator->get_realm();
        r2->begin_transaction();
        r2->read_group().get_table("class_object")->add_empty_row();
        r2->commit_transaction();

        r->refresh(); // would deadlock if there was a callback
    }

    SECTION("refresh() does not attempt to deliver stale results") {
        // Create version 1
        r->begin_transaction();
        table->add_empty_row();
        r->commit_transaction();

        r->begin_transaction();
        // Run async query for version 1
        coordinator->on_change();
        // Create version 2 without ever letting 1 be delivered
        table->add_empty_row();
        r->commit_transaction();

        // Give it a chance to deliver the async query results (and fail, becuse
        // they're for version 1 and the realm is at 2)
        r->refresh();
    }
}

TEST_CASE("results: error messages") {
    InMemoryTestFile config;
    config.schema = Schema{
        {"object", {
            {"value", PropertyType::String},
        }},
    };

    auto r = Realm::get_shared_realm(config);
    auto table = r->read_group().get_table("class_object");
    Results results(r, *table);

    r->begin_transaction();
    table->add_empty_row();
    r->commit_transaction();

    SECTION("out of bounds access") {
        REQUIRE_THROWS_WITH(results.get(5), "Requested index 5 greater than max 0");
    }

    SECTION("unsupported aggregate operation") {
        REQUIRE_THROWS_WITH(results.sum(0), "Cannot sum property 'value': operation not supported for 'string' properties");
    }
}

TEST_CASE("results: snapshots") {
    InMemoryTestFile config;
    config.cache = false;
    config.automatic_change_notifications = false;
    config.schema = Schema{
        {"object", {
            {"value", PropertyType::Int},
            {"array", PropertyType::Array|PropertyType::Object, "linked to object"}
        }},
        {"linked to object", {
            {"value", PropertyType::Int}
        }}
    };

    auto r = Realm::get_shared_realm(config);

    auto write = [&](auto&& f) {
        r->begin_transaction();
        f();
        r->commit_transaction();
        advance_and_notify(*r);
    };

    SECTION("snapshot of empty Results") {
        Results results;
        auto snapshot = results.snapshot();
        REQUIRE(snapshot.size() == 0);
    }

    SECTION("snapshot of Results based on Table") {
        auto table = r->read_group().get_table("class_object");
        Results results(r, *table);

        {
            // A newly-added row should not appear in the snapshot.
            auto snapshot = results.snapshot();
            REQUIRE(results.size() == 0);
            REQUIRE(snapshot.size() == 0);
            write([=]{
                table->add_empty_row();
            });
            REQUIRE(results.size() == 1);
            REQUIRE(snapshot.size() == 0);
        }

        {
            // Removing a row present in the snapshot should not affect the size of the snapshot,
            // but will result in the snapshot returning a detached row accessor.
            auto snapshot = results.snapshot();
            REQUIRE(results.size() == 1);
            REQUIRE(snapshot.size() == 1);
            write([=]{
                table->move_last_over(0);
            });
            REQUIRE(results.size() == 0);
            REQUIRE(snapshot.size() == 1);
            REQUIRE(!snapshot.get(0).is_attached());

            // Adding a row at the same index that was formerly present in the snapshot shouldn't
            // affect the state of the snapshot.
            write([=]{
                table->add_empty_row();
            });
            REQUIRE(snapshot.size() == 1);
            REQUIRE(!snapshot.get(0).is_attached());
        }
    }

    SECTION("snapshot of Results based on LinkView") {
        auto object = r->read_group().get_table("class_object");
        auto linked_to = r->read_group().get_table("class_linked to object");

        write([=]{
            object->add_empty_row();
        });

        LinkViewRef lv = object->get_linklist(1, 0);
        Results results(r, lv);

        {
            // A newly-added row should not appear in the snapshot.
            auto snapshot = results.snapshot();
            REQUIRE(results.size() == 0);
            REQUIRE(snapshot.size() == 0);
            write([=]{
                lv->add(linked_to->add_empty_row());
            });
            REQUIRE(results.size() == 1);
            REQUIRE(snapshot.size() == 0);
        }

        {
            // Removing a row from the link list should not affect the snapshot.
            auto snapshot = results.snapshot();
            REQUIRE(results.size() == 1);
            REQUIRE(snapshot.size() == 1);
            write([=]{
                lv->remove(0);
            });
            REQUIRE(results.size() == 0);
            REQUIRE(snapshot.size() == 1);
            REQUIRE(snapshot.get(0).is_attached());

            // Removing a row present in the snapshot from its table should result in the snapshot
            // returning a detached row accessor.
            write([=]{
                linked_to->remove(0);
            });
            REQUIRE(snapshot.size() == 1);
            REQUIRE(!snapshot.get(0).is_attached());

            // Adding a new row to the link list shouldn't affect the state of the snapshot.
            write([=]{
                lv->add(linked_to->add_empty_row());
            });
            REQUIRE(snapshot.size() == 1);
            REQUIRE(!snapshot.get(0).is_attached());
        }
    }

    SECTION("snapshot of Results based on Query") {
        auto table = r->read_group().get_table("class_object");
        Query q = table->column<Int>(0) > 0;
        Results results(r, std::move(q));

        {
            // A newly-added row should not appear in the snapshot.
            auto snapshot = results.snapshot();
            REQUIRE(results.size() == 0);
            REQUIRE(snapshot.size() == 0);
            write([=]{
                table->set_int(0, table->add_empty_row(), 1);
            });
            REQUIRE(results.size() == 1);
            REQUIRE(snapshot.size() == 0);
        }

        {
            // Updating a row to no longer match the query criteria should not affect the snapshot.
            auto snapshot = results.snapshot();
            REQUIRE(results.size() == 1);
            REQUIRE(snapshot.size() == 1);
            write([=]{
                table->set_int(0, 0, 0);
            });
            REQUIRE(results.size() == 0);
            REQUIRE(snapshot.size() == 1);
            REQUIRE(snapshot.get(0).is_attached());

            // Removing a row present in the snapshot from its table should result in the snapshot
            // returning a detached row accessor.
            write([=]{
                table->remove(0);
            });
            REQUIRE(snapshot.size() == 1);
            REQUIRE(!snapshot.get(0).is_attached());

            // Adding a new row that matches the query criteria shouldn't affect the state of the snapshot.
            write([=]{
                table->set_int(0, table->add_empty_row(), 1);
            });
            REQUIRE(snapshot.size() == 1);
            REQUIRE(!snapshot.get(0).is_attached());
        }
    }

    SECTION("snapshot of Results based on TableView from query") {
        auto table = r->read_group().get_table("class_object");
        Query q = table->column<Int>(0) > 0;
        Results results(r, q.find_all());

        {
            // A newly-added row should not appear in the snapshot.
            auto snapshot = results.snapshot();
            REQUIRE(results.size() == 0);
            REQUIRE(snapshot.size() == 0);
            write([=]{
                table->set_int(0, table->add_empty_row(), 1);
            });
            REQUIRE(results.size() == 1);
            REQUIRE(snapshot.size() == 0);
        }

        {
            // Updating a row to no longer match the query criteria should not affect the snapshot.
            auto snapshot = results.snapshot();
            REQUIRE(results.size() == 1);
            REQUIRE(snapshot.size() == 1);
            write([=]{
                table->set_int(0, 0, 0);
            });
            REQUIRE(results.size() == 0);
            REQUIRE(snapshot.size() == 1);
            REQUIRE(snapshot.get(0).is_attached());

            // Removing a row present in the snapshot from its table should result in the snapshot
            // returning a detached row accessor.
            write([=]{
                table->remove(0);
            });
            REQUIRE(snapshot.size() == 1);
            REQUIRE(!snapshot.get(0).is_attached());

            // Adding a new row that matches the query criteria shouldn't affect the state of the snapshot.
            write([=]{
                table->set_int(0, table->add_empty_row(), 1);
            });
            REQUIRE(snapshot.size() == 1);
            REQUIRE(!snapshot.get(0).is_attached());
        }
    }

    SECTION("snapshot of Results based on TableView from backlinks") {
        auto object = r->read_group().get_table("class_object");
        auto linked_to = r->read_group().get_table("class_linked to object");

        write([=]{
            linked_to->add_empty_row();
        });

        TableView backlinks = linked_to->get_backlink_view(0, object.get(), 1);
        Results results(r, std::move(backlinks));

        auto lv = object->get_linklist(1, object->add_empty_row());

        {
            // A newly-added row should not appear in the snapshot.
            auto snapshot = results.snapshot();
            REQUIRE(results.size() == 0);
            REQUIRE(snapshot.size() == 0);
            write([=]{
                lv->add(0);
            });
            REQUIRE(results.size() == 1);
            REQUIRE(snapshot.size() == 0);
        }

        {
            // Removing the link should not affect the snapshot.
            auto snapshot = results.snapshot();
            REQUIRE(results.size() == 1);
            REQUIRE(snapshot.size() == 1);
            write([=]{
                lv->remove(0);
            });
            REQUIRE(results.size() == 0);
            REQUIRE(snapshot.size() == 1);
            REQUIRE(snapshot.get(0).is_attached());

            // Removing a row present in the snapshot from its table should result in the snapshot
            // returning a detached row accessor.
            write([=]{
                object->remove(0);
            });
            REQUIRE(snapshot.size() == 1);
            REQUIRE(!snapshot.get(0).is_attached());

            // Adding a new link shouldn't affect the state of the snapshot.
            write([=]{
                object->add_empty_row();
                auto lv = object->get_linklist(1, object->add_empty_row());
                lv->add(0);
            });
            REQUIRE(snapshot.size() == 1);
            REQUIRE(!snapshot.get(0).is_attached());
        }
    }

    SECTION("snapshot of Results with notification callback registered") {
        auto table = r->read_group().get_table("class_object");
        Query q = table->column<Int>(0) > 0;
        Results results(r, q.find_all());

        auto token = results.add_notification_callback([&](CollectionChangeSet, std::exception_ptr err) {
            REQUIRE_FALSE(err);
        });
        advance_and_notify(*r);

        SECTION("snapshot of lvalue") {
            auto snapshot = results.snapshot();
            write([=] {
                table->set_int(0, table->add_empty_row(), 1);
            });
            REQUIRE(snapshot.size() == 0);
        }

        SECTION("snapshot of rvalue") {
            auto snapshot = std::move(results).snapshot();
            write([=] {
                table->set_int(0, table->add_empty_row(), 1);
            });
            REQUIRE(snapshot.size() == 0);
        }
    }

    SECTION("adding notification callback to snapshot throws") {
        auto table = r->read_group().get_table("class_object");
        Query q = table->column<Int>(0) > 0;
        Results results(r, q.find_all());
        auto snapshot = results.snapshot();
        CHECK_THROWS(snapshot.add_notification_callback([](CollectionChangeSet, std::exception_ptr) {}));
    }

    SECTION("accessors should return none for detached row") {
        auto table = r->read_group().get_table("class_object");
        write([=] {
            table->add_empty_row();
        });
        Results results(r, *table);
        auto snapshot = results.snapshot();
        write([=] {;
            table->clear();
        });

        REQUIRE_FALSE(snapshot.get(0).is_attached());
        REQUIRE_FALSE(snapshot.first()->is_attached());
        REQUIRE_FALSE(snapshot.last()->is_attached());
    }
}

TEST_CASE("results: distinct") {
    const int N = 10;
    InMemoryTestFile config;
    config.cache = false;
    config.automatic_change_notifications = false;

    auto r = Realm::get_shared_realm(config);
    r->update_schema({
        {"object", {
            {"num1", PropertyType::Int},
            {"string", PropertyType::String},
            {"num2", PropertyType::Int},
            {"num3", PropertyType::Int}
        }},
    });

    auto table = r->read_group().get_table("class_object");

    r->begin_transaction();
    table->add_empty_row(N);
    for (int i = 0; i < N; ++i) {
        table->set_int(0, i, i % 3);
        table->set_string(1, i, util::format("Foo_%1", i % 3).c_str());
        table->set_int(2, i, N - i);
        table->set_int(3, i, i % 2);
    }
    // table:
    //   0, Foo_0, 10,  0
    //   1, Foo_1,  9,  1
    //   2, Foo_2,  8,  0
    //   0, Foo_0,  7,  1
    //   1, Foo_1,  6,  0
    //   2, Foo_2,  5,  1
    //   0, Foo_0,  4,  0
    //   1, Foo_1,  3,  1
    //   2, Foo_2,  2,  0
    //   0, Foo_0,  1,  1

    r->commit_transaction();
    Results results(r, table->where());

    SECTION("Single integer property") {
        Results unique = results.distinct(SortDescriptor(results.get_tableview().get_parent(), {{0}}));
        // unique:
        //  0, Foo_0, 10
        //  1, Foo_1,  9
        //  2, Foo_2,  8
        REQUIRE(unique.size() == 3);
        REQUIRE(unique.get(0).get_int(2) == 10);
        REQUIRE(unique.get(1).get_int(2) == 9);
        REQUIRE(unique.get(2).get_int(2) == 8);
    }

    SECTION("Single integer via apply_ordering") {
        DescriptorOrdering ordering;
        ordering.append_sort(SortDescriptor(results.get_tableview().get_parent(), {{0}}));
        ordering.append_distinct(DistinctDescriptor(results.get_tableview().get_parent(), {{0}}));
        Results unique = results.apply_ordering(std::move(ordering));
        // unique:
        //  0, Foo_0, 10
        //  1, Foo_1,  9
        //  2, Foo_2,  8
        REQUIRE(unique.size() == 3);
        REQUIRE(unique.get(0).get_int(2) == 10);
        REQUIRE(unique.get(1).get_int(2) == 9);
        REQUIRE(unique.get(2).get_int(2) == 8);
    }

    SECTION("Single string property") {
        Results unique = results.distinct(SortDescriptor(results.get_tableview().get_parent(), {{1}}));
        // unique:
        //  0, Foo_0, 10
        //  1, Foo_1,  9
        //  2, Foo_2,  8
        REQUIRE(unique.size() == 3);
        REQUIRE(unique.get(0).get_int(2) == 10);
        REQUIRE(unique.get(1).get_int(2) == 9);
        REQUIRE(unique.get(2).get_int(2) == 8);
    }

    SECTION("Two integer properties combined") {
        Results unique = results.distinct(SortDescriptor(results.get_tableview().get_parent(), {{0}, {2}}));
        // unique is the same as the table
        REQUIRE(unique.size() == N);
        for (int i = 0; i < N; ++i) {
            REQUIRE(unique.get(i).get_string(1) == StringData(util::format("Foo_%1", i % 3).c_str()));
        }
    }

    SECTION("String and integer combined") {
        Results unique = results.distinct(SortDescriptor(results.get_tableview().get_parent(), {{2}, {1}}));
        // unique is the same as the table
        REQUIRE(unique.size() == N);
        for (int i = 0; i < N; ++i) {
            REQUIRE(unique.get(i).get_string(1) == StringData(util::format("Foo_%1", i % 3).c_str()));
        }
    }

    // This section and next section demonstrate that sort().distinct() != distinct().sort()
    SECTION("Order after sort and distinct") {
        Results reverse = results.sort(SortDescriptor(results.get_tableview().get_parent(), {{2}}, {true}));
        // reverse:
        //   0, Foo_0,  1
        //  ...
        //   0, Foo_0, 10
        REQUIRE(reverse.first()->get_int(2) == 1);
        REQUIRE(reverse.last()->get_int(2) == 10);

        // distinct() will be applied to the table, after sorting
        Results unique = reverse.distinct(SortDescriptor(reverse.get_tableview().get_parent(), {{0}}));
        // unique:
        //  0, Foo_0,  1
        //  2, Foo_2,  2
        //  1, Foo_1,  3
        REQUIRE(unique.size() == 3);
        REQUIRE(unique.get(0).get_int(2) == 1);
        REQUIRE(unique.get(1).get_int(2) == 2);
        REQUIRE(unique.get(2).get_int(2) == 3);
    }

    SECTION("Order after distinct and sort") {
        Results unique = results.distinct(SortDescriptor(results.get_tableview().get_parent(), {{0}}));
        // unique:
        //  0, Foo_0, 10
        //  1, Foo_1,  9
        //  2, Foo_2,  8
        REQUIRE(unique.size() == 3);
        REQUIRE(unique.first()->get_int(2) == 10);
        REQUIRE(unique.last()->get_int(2) == 8);

        // sort() is only applied to unique
        Results reverse = unique.sort(SortDescriptor(unique.get_tableview().get_parent(), {{2}}, {true}));
        // reversed:
        //  2, Foo_2,  8
        //  1, Foo_1,  9
        //  0, Foo_0, 10
        REQUIRE(reverse.size() == 3);
        REQUIRE(reverse.get(0).get_int(2) == 8);
        REQUIRE(reverse.get(1).get_int(2) == 9);
        REQUIRE(reverse.get(2).get_int(2) == 10);
    }

    SECTION("Chaining distinct") {
        Results first = results.distinct(SortDescriptor(results.get_tableview().get_parent(), {{0}}));
        REQUIRE(first.size() == 3);

        // distinct() will not discard the previous applied distinct() calls
        Results second = first.distinct(SortDescriptor(first.get_tableview().get_parent(), {{3}}));
        REQUIRE(second.size() == 2);
    }

    SECTION("Chaining sort") {
        using cols_0_3 = std::pair<size_t, size_t>;
        Results first = results.sort(SortDescriptor(results.get_tableview().get_parent(), {{0}}));
        Results second = first.sort(SortDescriptor(first.get_tableview().get_parent(), {{3}}));

        REQUIRE(second.size() == 10);
        // results are ordered first by the last sorted column
        // if any duplicates exist in that column, they are resolved by sorting the
        // previously sorted column. Eg. sort(a).sort(b) == sort(b, a)
        std::vector<cols_0_3> results
            = {{0, 0}, {0, 0}, {1, 0}, {2, 0}, {2, 0}, {0, 1}, {0, 1}, {1, 1}, {1, 1}, {2, 1}};
        for (size_t i = 0; i < results.size(); ++i) {
            REQUIRE(second.get(i).get_int(0) == results[i].first);
            REQUIRE(second.get(i).get_int(3) == results[i].second);
        }
    }

    SECTION("Distinct is carried over to new queries") {
        Results unique = results.distinct(SortDescriptor(results.get_tableview().get_parent(), {{0}}));
        // unique:
        //  0, Foo_0, 10
        //  1, Foo_1,  9
        //  2, Foo_2,  8
        REQUIRE(unique.size() == 3);

        Results filtered = unique.filter(Query(table->where().less(0, 2)));
        // filtered:
        //  0, Foo_0, 10
        //  1, Foo_1,  9
        REQUIRE(filtered.size() == 2);
        REQUIRE(filtered.get(0).get_int(2) == 10);
        REQUIRE(filtered.get(1).get_int(2) == 9);
    }

    SECTION("Distinct will not forget previous query") {
        Results filtered = results.filter(Query(table->where().greater(2, 5)));
        // filtered:
        //   0, Foo_0, 10
        //   1, Foo_1,  9
        //   2, Foo_2,  8
        //   0, Foo_0,  7
        //   1, Foo_1,  6
        REQUIRE(filtered.size() == 5);

        Results unique = filtered.distinct(SortDescriptor(filtered.get_tableview().get_parent(), {{0}}));
        // unique:
        //   0, Foo_0, 10
        //   1, Foo_1,  9
        //   2, Foo_2,  8
        REQUIRE(unique.size() == 3);
        REQUIRE(unique.get(0).get_int(2) == 10);
        REQUIRE(unique.get(1).get_int(2) == 9);
        REQUIRE(unique.get(2).get_int(2) == 8);

        Results further_filtered = unique.filter(Query(table->where().equal(2, 9)));
        // further_filtered:
        //   1, Foo_1,  9
        REQUIRE(further_filtered.size() == 1);
        REQUIRE(further_filtered.get(0).get_int(2) == 9);
    }
}

TEST_CASE("results: sort") {
    InMemoryTestFile config;
    config.cache = false;
    config.schema = Schema{
        {"object", {
            {"value", PropertyType::Int},
            {"bool", PropertyType::Bool},
            {"data prop", PropertyType::Data},
            {"link", PropertyType::Object|PropertyType::Nullable, "object 2"},
            {"array", PropertyType::Object|PropertyType::Array, "object 2"},
        }},
        {"object 2", {
            {"value", PropertyType::Int},
            {"link", PropertyType::Object|PropertyType::Nullable, "object"},
        }},
    };

    auto realm = Realm::get_shared_realm(config);
    auto table = realm->read_group().get_table("class_object");
    auto table2 = realm->read_group().get_table("class_object 2");
    Results r(realm, *table);

    SECTION("invalid keypaths") {
        SECTION("empty property name") {
            REQUIRE_THROWS_WITH(r.sort({{"", true}}), "Cannot sort on key path '': missing property name.");
            REQUIRE_THROWS_WITH(r.sort({{".", true}}), "Cannot sort on key path '.': missing property name.");
            REQUIRE_THROWS_WITH(r.sort({{"link.", true}}), "Cannot sort on key path 'link.': missing property name.");
            REQUIRE_THROWS_WITH(r.sort({{".value", true}}), "Cannot sort on key path '.value': missing property name.");
            REQUIRE_THROWS_WITH(r.sort({{"link..value", true}}), "Cannot sort on key path 'link..value': missing property name.");
        }
        SECTION("bad property name") {
            REQUIRE_THROWS_WITH(r.sort({{"not a property", true}}),
                                "Cannot sort on key path 'not a property': property 'object.not a property' does not exist.");
            REQUIRE_THROWS_WITH(r.sort({{"link.not a property", true}}),
                                "Cannot sort on key path 'link.not a property': property 'object 2.not a property' does not exist.");
        }
        SECTION("subscript primitive") {
            REQUIRE_THROWS_WITH(r.sort({{"value.link", true}}),
                                "Cannot sort on key path 'value.link': property 'object.value' of type 'int' may only be the final property in the key path.");
        }
        SECTION("end in link") {
            REQUIRE_THROWS_WITH(r.sort({{"link", true}}),
                                "Cannot sort on key path 'link': property 'object.link' of type 'object' cannot be the final property in the key path.");
            REQUIRE_THROWS_WITH(r.sort({{"link.link", true}}),
                                "Cannot sort on key path 'link.link': property 'object 2.link' of type 'object' cannot be the final property in the key path.");
        }
        SECTION("sort involving bad property types") {
            REQUIRE_THROWS_WITH(r.sort({{"array", true}}),
                                "Cannot sort on key path 'array': property 'object.array' is of unsupported type 'array'.");
            REQUIRE_THROWS_WITH(r.sort({{"array.value", true}}),
                                "Cannot sort on key path 'array.value': property 'object.array' is of unsupported type 'array'.");
            REQUIRE_THROWS_WITH(r.sort({{"link.link.array.value", true}}),
                                "Cannot sort on key path 'link.link.array.value': property 'object.array' is of unsupported type 'array'.");
            REQUIRE_THROWS_WITH(r.sort({{"data prop", true}}),
                                "Cannot sort on key path 'data prop': property 'object.data prop' is of unsupported type 'data'.");
        }
    }

    realm->begin_transaction();
    table->add_empty_row(4);
    table2->add_empty_row(4);
    for (int i = 0; i < 4; ++i) {
        table->set_int(0, i, (i + 2) % 4);
        table->set_bool(1, i, i % 2);
        table->set_link(3, i, 3 - i);

        table2->set_int(0, i, (i + 1) % 4);
        table2->set_link(1, i, i);
    }
    realm->commit_transaction();
    /*
     | index | value | bool | link.value | link.link.value |
     |-------|-------|------|------------|-----------------|
     | 0     | 2     | 0    | 0          | 1               |
     | 1     | 3     | 1    | 3          | 0               |
     | 2     | 0     | 0    | 2          | 3               |
     | 3     | 1     | 1    | 1          | 2               |
     */

    #define REQUIRE_ORDER(sort, ...) do { \
        std::vector<size_t> expected = {__VA_ARGS__}; \
        auto results = sort; \
        REQUIRE(results.size() == expected.size()); \
        for (size_t i = 0; i < expected.size(); ++i) \
            REQUIRE(results.get(i).get_index() == expected[i]); \
    } while (0)

    SECTION("sort on single property") {
        REQUIRE_ORDER((r.sort({{"value", true}})),
                      2, 3, 0, 1);
        REQUIRE_ORDER((r.sort({{"value", false}})),
                      1, 0, 3, 2);
    }

    SECTION("sort on two properties") {
        REQUIRE_ORDER((r.sort({{"bool", true}, {"value", true}})),
                      2, 0, 3, 1);
        REQUIRE_ORDER((r.sort({{"bool", false}, {"value", true}})),
                      3, 1, 2, 0);
        REQUIRE_ORDER((r.sort({{"bool", true}, {"value", false}})),
                      0, 2, 1, 3);
        REQUIRE_ORDER((r.sort({{"bool", false}, {"value", false}})),
                      1, 3, 0, 2);
    }
    SECTION("sort over link") {
        REQUIRE_ORDER((r.sort({{"link.value", true}})),
                      0, 3, 2, 1);
        REQUIRE_ORDER((r.sort({{"link.value", false}})),
                      1, 2, 3, 0);
    }
    SECTION("sort over two links") {
        REQUIRE_ORDER((r.sort({{"link.link.value", true}})),
                      1, 0, 3, 2);
        REQUIRE_ORDER((r.sort({{"link.link.value", false}})),
                      2, 3, 0, 1);
    }
}

struct ResultsFromTable {
    static Results call(std::shared_ptr<Realm> r, Table* table) {
        return Results(std::move(r), *table);
    }
};
struct ResultsFromQuery {
    static Results call(std::shared_ptr<Realm> r, Table* table) {
        return Results(std::move(r), table->where());
    }
};
struct ResultsFromTableView {
    static Results call(std::shared_ptr<Realm> r, Table* table) {
        return Results(std::move(r), table->where().find_all());
    }
};
struct ResultsFromLinkView {
    static Results call(std::shared_ptr<Realm> r, Table* table) {
        r->begin_transaction();
        auto link_table = r->read_group().get_table("class_linking_object");
        link_table->add_empty_row(1);
        auto link_view = link_table->get_linklist(0, 0);
        for (size_t i = 0; i < table->size(); ++i)
            link_view->add(i);
        r->commit_transaction();
        return Results(r, link_view);
    }
};

TEMPLATE_TEST_CASE("results: aggregate", ResultsFromTable, ResultsFromQuery, ResultsFromTableView, ResultsFromLinkView) {
    InMemoryTestFile config;
    config.cache = false;
    config.automatic_change_notifications = false;

    auto r = Realm::get_shared_realm(config);
    r->update_schema({
        {"object", {
            {"int", PropertyType::Int|PropertyType::Nullable},
            {"float", PropertyType::Float|PropertyType::Nullable},
            {"double", PropertyType::Double|PropertyType::Nullable},
            {"date", PropertyType::Date|PropertyType::Nullable},
        }},
        {"linking_object", {
            {"link", PropertyType::Array|PropertyType::Object, "object"}
        }},
    });

    auto table = r->read_group().get_table("class_object");

    SECTION("one row with null values") {
        r->begin_transaction();
        table->add_empty_row(3);

        table->set_int(0, 1, 0);
        table->set_float(1, 1, 0.f);
        table->set_double(2, 1, 0.0);
        table->set_timestamp(3, 1, Timestamp(0, 0));

        table->set_int(0, 2, 2);
        table->set_float(1, 2, 2.f);
        table->set_double(2, 2, 2.0);
        table->set_timestamp(3, 2, Timestamp(2, 0));
        // table:
        //  null, null, null,  null,
        //  0,    0,    0,    (0, 0)
        //  2,    2,    2,    (2, 0)
        r->commit_transaction();

        Results results = TestType::call(r, table.get());

        SECTION("max") {
            REQUIRE(results.max(0)->get_int() == 2);
            REQUIRE(results.max(1)->get_float() == 2.f);
            REQUIRE(results.max(2)->get_double() == 2.0);
            REQUIRE(results.max(3)->get_timestamp() == Timestamp(2, 0));
        }

        SECTION("min") {
            REQUIRE(results.min(0)->get_int() == 0);
            REQUIRE(results.min(1)->get_float() == 0.f);
            REQUIRE(results.min(2)->get_double() == 0.0);
            REQUIRE(results.min(3)->get_timestamp() == Timestamp(0, 0));
        }

        SECTION("average") {
            REQUIRE(results.average(0) == 1.0);
            REQUIRE(results.average(1) == 1.0);
            REQUIRE(results.average(2) == 1.0);
            REQUIRE_THROWS_AS(results.average(3), Results::UnsupportedColumnTypeException);
        }

        SECTION("sum") {
            REQUIRE(results.sum(0)->get_int() == 2);
            REQUIRE(results.sum(1)->get_double() == 2.0);
            REQUIRE(results.sum(2)->get_double() == 2.0);
            REQUIRE_THROWS_AS(results.sum(3), Results::UnsupportedColumnTypeException);
        }
    }

    SECTION("rows with all null values") {
        r->begin_transaction();
        table->add_empty_row(3);
        // table:
        //  null, null, null,  null,  null
        //  null, null, null,  null,  null
        //  null, null, null,  null,  null
        r->commit_transaction();

        Results results = TestType::call(r, table.get());

        SECTION("max") {
            REQUIRE(!results.max(0));
            REQUIRE(!results.max(1));
            REQUIRE(!results.max(2));
            REQUIRE(!results.max(3));
        }

        SECTION("min") {
            REQUIRE(!results.min(0));
            REQUIRE(!results.min(1));
            REQUIRE(!results.min(2));
            REQUIRE(!results.min(3));
        }

        SECTION("average") {
            REQUIRE(!results.average(0));
            REQUIRE(!results.average(1));
            REQUIRE(!results.average(2));
            REQUIRE_THROWS_AS(results.average(3), Results::UnsupportedColumnTypeException);
        }

        SECTION("sum") {
            REQUIRE(results.sum(0)->get_int() == 0);
            REQUIRE(results.sum(1)->get_double() == 0.0);
            REQUIRE(results.sum(2)->get_double() == 0.0);
            REQUIRE_THROWS_AS(results.sum(3), Results::UnsupportedColumnTypeException);
        }
    }

    SECTION("empty") {
        Results results = TestType::call(r, table.get());

        SECTION("max") {
            REQUIRE(!results.max(0));
            REQUIRE(!results.max(1));
            REQUIRE(!results.max(2));
            REQUIRE(!results.max(3));
        }

        SECTION("min") {
            REQUIRE(!results.min(0));
            REQUIRE(!results.min(1));
            REQUIRE(!results.min(2));
            REQUIRE(!results.min(3));
        }

        SECTION("average") {
            REQUIRE(!results.average(0));
            REQUIRE(!results.average(1));
            REQUIRE(!results.average(2));
            REQUIRE_THROWS_AS(results.average(3), Results::UnsupportedColumnTypeException);
        }

        SECTION("sum") {
            REQUIRE(results.sum(0)->get_int() == 0);
            REQUIRE(results.sum(1)->get_double() == 0.0);
            REQUIRE(results.sum(2)->get_double() == 0.0);
            REQUIRE_THROWS_AS(results.sum(3), Results::UnsupportedColumnTypeException);
        }
    }
}

TEST_CASE("results: set property value on all objects", "[batch_updates]") {

    InMemoryTestFile config;
    config.automatic_change_notifications = false;
    config.cache = false;
    config.schema = Schema{
        {"AllTypes", {
            {"pk", PropertyType::Int, Property::IsPrimary{true}},
            {"bool", PropertyType::Bool},
            {"int", PropertyType::Int},
            {"float", PropertyType::Float},
            {"double", PropertyType::Double},
            {"string", PropertyType::String},
            {"data", PropertyType::Data},
            {"date", PropertyType::Date},
            {"object", PropertyType::Object|PropertyType::Nullable, "AllTypes"},
            {"list", PropertyType::Array|PropertyType::Object, "AllTypes"},

            {"bool array", PropertyType::Array|PropertyType::Bool},
            {"int array", PropertyType::Array|PropertyType::Int},
            {"float array", PropertyType::Array|PropertyType::Float},
            {"double array", PropertyType::Array|PropertyType::Double},
            {"string array", PropertyType::Array|PropertyType::String},
            {"data array", PropertyType::Array|PropertyType::Data},
            {"date array", PropertyType::Array|PropertyType::Date},
            {"object array", PropertyType::Array|PropertyType::Object, "AllTypes"},
        }, {
           {"parents", PropertyType::LinkingObjects|PropertyType::Array, "AllTypes", "object"},
        }}
    };
    config.schema_version = 0;
    auto realm = Realm::get_shared_realm(config);
    auto table = realm->read_group().get_table("class_AllTypes");
    realm->begin_transaction();
    table->add_empty_row(2);
    realm->commit_transaction();
    Results r(realm, *table);

    TestContext ctx(realm);

    SECTION("non-existing property name") {
        realm->begin_transaction();
        REQUIRE_THROWS_AS(r.set_property_value(ctx, "i dont exist", util::Any(false)), Results::InvalidPropertyException);
        realm->cancel_transaction();
    }

    SECTION("readonly property") {
        realm->begin_transaction();
        REQUIRE_THROWS_AS(r.set_property_value(ctx, "parents", util::Any(false)), ReadOnlyPropertyException);
        realm->cancel_transaction();
    }

    SECTION("primarykey property") {
        realm->begin_transaction();
        REQUIRE_THROWS_AS(r.set_property_value(ctx, "pk", util::Any(1)), std::logic_error);
        realm->cancel_transaction();
    }

    SECTION("set property value") {
        realm->begin_transaction();

        r.set_property_value<util::Any>(ctx, "bool", util::Any(true));
        for (size_t i = 0; i < r.size(); i++) {
            CHECK(r.get(i).get_bool(1) == true);
        }

        r.set_property_value(ctx, "int", util::Any(INT64_C(42)));
        for (size_t i = 0; i < r.size(); i++) {
            CHECK(r.get(i).get_int(2) == 42);
        }

        r.set_property_value(ctx, "float", util::Any(1.23f));
        for (size_t i = 0; i < r.size(); i++) {
            CHECK(r.get(i).get_float(3) == 1.23f);
        }

        r.set_property_value(ctx, "double", util::Any(1.234));
        for (size_t i = 0; i < r.size(); i++) {
            CHECK(r.get(i).get_double(4) == 1.234);
        }

        r.set_property_value(ctx, "string", util::Any(std::string("abc")));
        for (size_t i = 0; i < r.size(); i++) {
            CHECK(r.get(i).get_string(5) == "abc");
        }

        r.set_property_value(ctx, "data", util::Any(std::string("abc")));
        for (size_t i = 0; i < r.size(); i++) {
            CHECK(r.get(i).get_binary(6) == BinaryData("abc", 3));
        }

        util::Any timestamp = Timestamp(1, 2);
        r.set_property_value(ctx, "date", timestamp);
        for (size_t i = 0; i < r.size(); i++) {
            CHECK(r.get(i).get_timestamp(7) == any_cast<Timestamp>(timestamp));
        }

        size_t object_ndx = table->add_empty_row();
        Object linked_obj(realm, "AllTypes", object_ndx);
        r.set_property_value(ctx, "object", util::Any(linked_obj));
        for (size_t i = 0; i < r.size(); i++) {
            CHECK(r.get(i).get_link(8) == object_ndx);
        }

        size_t list_object_ndx = table->add_empty_row();
        Object list_object(realm, "AllTypes", list_object_ndx);
        r.set_property_value(ctx, "list", util::Any(AnyVector{list_object, list_object}));
        for (size_t i = 0; i < r.size(); i++) {
            auto list = r.get(i).get_linklist(9);
            CHECK(list->size() == 2);
            CHECK(list->get(0).get_index() == list_object_ndx);
            CHECK(list->get(1).get_index() == list_object_ndx);
        }

        auto check_array = [&](size_t col, auto... values) {
            size_t rows = r.size();
            for (size_t i = 0; i < rows; ++i) {
                RowExpr row = r.get(i);
                auto table = row.get_subtable(col);
                size_t j = 0;
                for (auto& value : {values...}) {
                    CAPTURE(j);
                    REQUIRE(j < row.get_subtable_size(col));
                    REQUIRE(value == table->get<typename std::decay<decltype(value)>::type>(0, j));
                    ++j;
                }
            }
        };

        r.set_property_value(ctx, "bool array", util::Any(AnyVec{true, false}));
        check_array(10, true, false);

        r.set_property_value(ctx, "int array", util::Any(AnyVec{INT64_C(5), INT64_C(6)}));
        check_array(11, INT64_C(5), INT64_C(6));

        r.set_property_value(ctx, "float array", util::Any(AnyVec{1.1f, 2.2f}));
        check_array(12, 1.1f, 2.2f);

        r.set_property_value(ctx, "double array", util::Any(AnyVec{3.3, 4.4}));
        check_array(13, 3.3, 4.4);

        r.set_property_value(ctx, "string array", util::Any(AnyVec{"a"s, "b"s, "c"s}));
        check_array(14, StringData("a"), StringData("b"), StringData("c"));
 
        r.set_property_value(ctx, "data array", util::Any(AnyVec{"d"s, "e"s, "f"s}));
        check_array(15, BinaryData("d",1), BinaryData("e",1), BinaryData("f",1));

        r.set_property_value(ctx, "date array", util::Any(AnyVec{Timestamp(10,20), Timestamp(20,30), Timestamp(30,40)}));
        check_array(16, Timestamp(10,20), Timestamp(20,30), Timestamp(30,40));
    }
}

TEST_CASE("results: limit", "[limit]") {
    InMemoryTestFile config;
    config.cache = false;
    config.automatic_change_notifications = false;
    config.schema = Schema{
        {"object", {
            {"value", PropertyType::Int},
        }},
    };

    auto realm = Realm::get_shared_realm(config);
    auto table = realm->read_group().get_table("class_object");

    realm->begin_transaction();
    table->add_empty_row(8);
    for (int i = 0; i < 8; ++i) {
        table->set_int(0, i, (i + 2) % 4);
    }
    realm->commit_transaction();
    Results r(realm, *table);

    SECTION("unsorted") {
        REQUIRE(r.limit(0).size() == 0);
        REQUIRE_ORDER(r.limit(1), 0);
        REQUIRE_ORDER(r.limit(2), 0, 1);
        REQUIRE_ORDER(r.limit(8), 0, 1, 2, 3, 4, 5, 6, 7);
        REQUIRE_ORDER(r.limit(100), 0, 1, 2, 3, 4, 5, 6, 7);
    }

    SECTION("sorted") {
        auto sorted = r.sort({{"value", true}});
        REQUIRE(sorted.limit(0).size() == 0);
        REQUIRE_ORDER(sorted.limit(1), 2);
        REQUIRE_ORDER(sorted.limit(2), 2, 6);
        REQUIRE_ORDER(sorted.limit(8), 2, 6, 3, 7, 0, 4, 1, 5);
        REQUIRE_ORDER(sorted.limit(100), 2, 6, 3, 7, 0, 4, 1, 5);
    }

    SECTION("sort after limit") {
        REQUIRE(r.limit(0).sort({{"value", true}}).size() == 0);
        REQUIRE_ORDER(r.limit(1).sort({{"value", true}}), 0);
        REQUIRE_ORDER(r.limit(3).sort({{"value", true}}), 2, 0, 1);
        REQUIRE_ORDER(r.limit(8).sort({{"value", true}}), 2, 6, 3, 7, 0, 4, 1, 5);
        REQUIRE_ORDER(r.limit(100).sort({{"value", true}}), 2, 6, 3, 7, 0, 4, 1, 5);
    }

    SECTION("distinct") {
        auto sorted = r.distinct({"value"});
        REQUIRE(sorted.limit(0).size() == 0);
        REQUIRE_ORDER(sorted.limit(1), 0);
        REQUIRE_ORDER(sorted.limit(2), 0, 1);
        REQUIRE_ORDER(sorted.limit(8), 0, 1, 2, 3);

        sorted = r.sort({{"value", true}}).distinct({"value"});
        REQUIRE(sorted.limit(0).size() == 0);
        REQUIRE_ORDER(sorted.limit(1), 2);
        REQUIRE_ORDER(sorted.limit(2), 2, 3);
        REQUIRE_ORDER(sorted.limit(8), 2, 3, 0, 1);
    }

    SECTION("notifications on results using all descriptor types") {
        r = r.distinct({"value"}).sort({{"value", false}}).limit(2);
        int notification_calls = 0;
        auto token = r.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            if (notification_calls == 0) {
                REQUIRE(c.empty());
                REQUIRE(r.size() == 2);
                REQUIRE(r.get(0).get_int(0) == 3);
                REQUIRE(r.get(1).get_int(0) == 2);
            } else if (notification_calls == 1) {
                REQUIRE(!c.empty());
                REQUIRE_INDICES(c.insertions, 0);
                REQUIRE_INDICES(c.deletions, 1);
                REQUIRE(c.moves.size() == 0);
                REQUIRE(c.modifications.count() == 0);
                REQUIRE(r.size() == 2);
                REQUIRE(r.get(0).get_int(0) == 5);
                REQUIRE(r.get(1).get_int(0) == 3);
            }
            ++notification_calls;
        });
        advance_and_notify(*realm);
        REQUIRE(notification_calls == 1);
        realm->begin_transaction();
        table->add_empty_row(1);
        table->set_int(0, 8, 5);
        realm->commit_transaction();
        advance_and_notify(*realm);
        REQUIRE(notification_calls == 2);
    }

    SECTION("notifications on only limited results") {
        r = r.limit(2);
        int notification_calls = 0;
        auto token = r.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr err) {
            REQUIRE_FALSE(err);
            if (notification_calls == 0) {
                REQUIRE(c.empty());
                REQUIRE(r.size() == 2);
            } else if (notification_calls == 1) {
                REQUIRE(!c.empty());
                REQUIRE(c.insertions.count() == 0);
                REQUIRE(c.deletions.count() == 0);
                REQUIRE(c.modifications.count() == 1);
                REQUIRE_INDICES(c.modifications, 1);
                REQUIRE(r.size() == 2);
            }
            ++notification_calls;
        });
        advance_and_notify(*realm);
        REQUIRE(notification_calls == 1);
        realm->begin_transaction();
        table->set_int(0, 1, 5);
        realm->commit_transaction();
        advance_and_notify(*realm);
        REQUIRE(notification_calls == 2);
    }

    SECTION("does not support further filtering") {
        auto limited = r.limit(0);
        REQUIRE_THROWS_AS(limited.filter(table->where()), Results::UnimplementedOperationException);
    }
}
