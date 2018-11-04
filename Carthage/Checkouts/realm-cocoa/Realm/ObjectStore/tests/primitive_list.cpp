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
#include "util/templated_test_case.hpp"
#include "util/test_file.hpp"

#include "binding_context.hpp"
#include "list.hpp"
#include "object.hpp"
#include "object_schema.hpp"
#include "property.hpp"
#include "results.hpp"
#include "schema.hpp"
#include "thread_safe_reference.hpp"

#include "impl/realm_coordinator.hpp"
#include "impl/object_accessor_impl.hpp"

#include <realm/group_shared.hpp>
#include <realm/link_view.hpp>
#include <realm/query_expression.hpp>
#include <realm/version.hpp>

#include <numeric>

using namespace realm;

template<PropertyType prop_type, typename T>
struct Base {
    using Type = T;
    using Wrapped = T;
    using Boxed = T;

    static PropertyType property_type() { return prop_type; }
    static util::Any to_any(T value) { return value; }

    template<typename Fn>
    static auto unwrap(T value, Fn&& fn) { return fn(value); }

    static T min() { abort(); }
    static T max() { abort(); }
    static T sum() { abort(); }
    static double average() { abort(); }

    static bool can_sum() { return std::is_arithmetic<T>::value; }
    static bool can_average() { return std::is_arithmetic<T>::value; }
    static bool can_minmax() { return std::is_arithmetic<T>::value; }
};

struct Int : Base<PropertyType::Int, int64_t> {
    static std::vector<int64_t> values() { return {3, 1, 2}; }
    static int64_t min() { return 1; }
    static int64_t max() { return 3; }
    static int64_t sum() { return 6; }
    static double average() { return 2.0; }
};

struct Bool : Base<PropertyType::Bool, bool> {
    static std::vector<bool> values() { return {true, false}; }
    static bool can_sum() { return false; }
    static bool can_average() { return false; }
    static bool can_minmax() { return false; }
};

struct Float : Base<PropertyType::Float, float> {
    static std::vector<float> values() { return {3.3f, 1.1f, 2.2f}; }
    static float min() { return 1.1f; }
    static float max() { return 3.3f; }
    static auto sum() { return Approx(6.6f); }
    static auto average() { return Approx(2.2f); }
};

struct Double : Base<PropertyType::Double, double> {
    static std::vector<double> values() { return {3.3, 1.1, 2.2}; }
    static double min() { return 1.1; }
    static double max() { return 3.3; }
    static auto sum() { return Approx(6.6); }
    static auto average() { return Approx(2.2); }
};

struct String : Base<PropertyType::String, StringData> {
    using Boxed = std::string;
    static std::vector<StringData> values() { return {"c", "a", "b"}; }
    static util::Any to_any(StringData value) { return value ? std::string(value) : util::Any(); }
};

struct Binary : Base<PropertyType::Data, BinaryData> {
    using Boxed = std::string;
    static std::vector<BinaryData> values() { return {BinaryData("a", 1)}; }
    static util::Any to_any(BinaryData value) { return value ? std::string(value) : util::Any(); }
};

struct Date : Base<PropertyType::Date, Timestamp> {
    static std::vector<Timestamp> values() { return {Timestamp(1, 1)}; }
    static bool can_minmax() { return true; }
    static Timestamp min() { return Timestamp(1, 1); }
    static Timestamp max() { return Timestamp(1, 1); }
};

template<typename BaseT>
struct BoxedOptional : BaseT {
    using Type = util::Optional<typename BaseT::Type>;
    using Boxed = Type;
    static PropertyType property_type() { return BaseT::property_type()|PropertyType::Nullable; }
    static std::vector<Type> values()
    {
        std::vector<Type> ret;
        for (auto v : BaseT::values())
            ret.push_back(Type(v));
        ret.push_back(util::none);
        return ret;
    }
    static auto unwrap(Type value) { return *value; }
    static util::Any to_any(Type value) { return value ? util::Any(*value) : util::Any(); }

    template<typename Fn>
    static auto unwrap(Type value, Fn&& fn) { return value ? fn(*value) : fn(null()); }
};

template<typename BaseT>
struct UnboxedOptional : BaseT {
    static PropertyType property_type() { return BaseT::property_type()|PropertyType::Nullable; }
    static auto values() -> decltype(BaseT::values())
    {
        auto ret = BaseT::values();
        ret.push_back(typename BaseT::Type());
        return ret;
    }
};

template<typename T>
T get(Mixed) { abort(); }

template<> int64_t get(Mixed m) { return m.get_int(); }
template<> float get(Mixed m) { return m.get_type() == type_Float ? m.get_float() : static_cast<float>(m.get_double()); }
template<> double get(Mixed m) { return m.get_double(); }
template<> Timestamp get(Mixed m) { return m.get_timestamp(); }

namespace realm {
template<typename T>
bool operator==(List const& list, std::vector<T> const& values) {
    if (list.size() != values.size())
        return false;
    for (size_t i = 0; i < values.size(); ++i) {
        if (list.get<T>(i) != values[i])
            return false;
    }
    return true;
}

template<typename T>
bool operator==(Results& results, std::vector<T> const& values) {
    if (results.size() != values.size())
        return false;
    for (size_t i = 0; i < values.size(); ++i) {
        if (results.get<T>(i) != values[i])
            return false;
    }
    return true;
}
}

struct StringifyingContext {
    template<typename T>
    std::string box(T value)
    {
        std::stringstream ss;
        ss << value;
        return ss.str();
    }

    std::string box(RowExpr row) { return util::to_string(row.get_index()); }
};

namespace Catch {
template<>
struct StringMaker<List> {
    static std::string convert(List const& list)
    {
        std::stringstream ss;
        auto type = list.get_type();
        ss << string_for_property_type(type & ~PropertyType::Flags);
        if (is_nullable(type))
            ss << "?";
        ss << "{";

        StringifyingContext ctx;
        for (size_t i = 0, count = list.size(); i < count; ++i)
            ss << list.get(ctx, i) << ", ";
        auto str = ss.str();
        str.pop_back();
        str.back() = '}';
        return str;
    }
};
template<>
struct StringMaker<Results> {
    static std::string convert(Results const& r)
    {
        auto& results = const_cast<Results&>(r);
        std::stringstream ss;
        auto type = results.get_type();
        ss << string_for_property_type(type & ~PropertyType::Flags);
        if (is_nullable(type))
            ss << "?";
        ss << "{";

        StringifyingContext ctx;
        for (size_t i = 0, count = results.size(); i < count; ++i)
            ss << results.get(ctx, i) << ", ";
        auto str = ss.str();
        str.pop_back();
        str.back() = '}';
        return str;
    }
};
template<>
struct StringMaker<util::None> {
    static std::string convert(util::None)
    {
        return "[none]";
    }
};
} // namespace Catch

struct less {
    template<class T, class U>
    auto operator()(T&& a, U&& b) const noexcept { return a < b; }
};
struct greater {
    template<class T, class U>
    auto operator()(T&& a, U&& b) const noexcept { return a > b; }
};

template<>
auto less::operator()<Timestamp&, Timestamp&>(Timestamp& a, Timestamp& b) const noexcept
{
    if (b.is_null())
        return false;
    if (a.is_null())
        return true;
    return a < b;
}

template<>
auto greater::operator()<Timestamp&, Timestamp&>(Timestamp& a, Timestamp& b) const noexcept
{
    if (a.is_null())
        return false;
    if (b.is_null())
        return true;
    return a > b;
}

TEMPLATE_TEST_CASE("primitive list", ::Int, ::Bool, ::Float, ::Double, ::String, ::Binary, ::Date,
                   BoxedOptional<::Int>, BoxedOptional<::Bool>, BoxedOptional<::Float>, BoxedOptional<::Double>,
                   UnboxedOptional<::String>, UnboxedOptional<::Binary>, UnboxedOptional<::Date>) {
    auto values = TestType::values();
    using T = typename TestType::Type;
    using W = typename TestType::Wrapped;
    using Boxed = typename TestType::Boxed;

    InMemoryTestFile config;
    config.automatic_change_notifications = false;
    config.cache = false;
    config.schema = Schema{
        {"object", {
            {"value", PropertyType::Array|TestType::property_type()}
        }},
    };
    auto r = Realm::get_shared_realm(config);

    auto table = r->read_group().get_table("class_object");
    r->begin_transaction();
    table->add_empty_row();

    List list(r, *table, 0, 0);
    auto results = list.as_results();
    CppContext ctx(r);

    SECTION("get_realm()") {
        REQUIRE(list.get_realm() == r);
        REQUIRE(results.get_realm() == r);
    }

    SECTION("get_query()") {
        REQUIRE(list.get_query().count() == 0);
        REQUIRE(results.get_query().count() == 0);
        list.add(static_cast<T>(values[0]));
        REQUIRE(list.get_query().count() == 1);
        REQUIRE(results.get_query().count() == 1);
    }

    SECTION("get_origin_row_index()") {
        REQUIRE(list.get_origin_row_index() == 0);
        table->insert_empty_row(0);
        REQUIRE(list.get_origin_row_index() == 1);
    }

    SECTION("get_type()") {
        REQUIRE(list.get_type() == TestType::property_type());
        REQUIRE(results.get_type() == TestType::property_type());
    }

    SECTION("get_object_type()") {
        REQUIRE(results.get_object_type() == StringData());
    }

    SECTION("is_valid()") {
        REQUIRE(list.is_valid());
        REQUIRE(results.is_valid());

        SECTION("invalidate") {
            r->invalidate();
            REQUIRE_FALSE(list.is_valid());
            REQUIRE_FALSE(results.is_valid());
        }

        SECTION("close") {
            r->close();
            REQUIRE_FALSE(list.is_valid());
            REQUIRE_FALSE(results.is_valid());
        }

        SECTION("delete row") {
            table->move_last_over(0);
            REQUIRE_FALSE(list.is_valid());
            REQUIRE_FALSE(results.is_valid());
        }

        SECTION("rollback transaction creating list") {
            r->cancel_transaction();
            REQUIRE_FALSE(list.is_valid());
            REQUIRE_FALSE(results.is_valid());
        }
    }

    SECTION("verify_attached()") {
        REQUIRE_NOTHROW(list.verify_attached());

        SECTION("invalidate") {
            r->invalidate();
            REQUIRE_THROWS(list.verify_attached());
        }

        SECTION("close") {
            r->close();
            REQUIRE_THROWS(list.verify_attached());
        }

        SECTION("delete row") {
            table->move_last_over(0);
            REQUIRE_THROWS(list.verify_attached());
        }

        SECTION("rollback transaction creating list") {
            r->cancel_transaction();
            REQUIRE_THROWS(list.verify_attached());
        }
    }

    SECTION("verify_in_transaction()") {
        REQUIRE_NOTHROW(list.verify_in_transaction());

        SECTION("invalidate") {
            r->invalidate();
            REQUIRE_THROWS(list.verify_in_transaction());
        }

        SECTION("close") {
            r->close();
            REQUIRE_THROWS(list.verify_in_transaction());
        }

        SECTION("delete row") {
            table->move_last_over(0);
            REQUIRE_THROWS(list.verify_in_transaction());
        }

        SECTION("end write") {
            r->commit_transaction();
            REQUIRE_THROWS(list.verify_in_transaction());
        }
    }

    if (!list.is_valid() || !r->is_in_transaction())
        return;

    for (T value : values)
        list.add(value);

    SECTION("move()") {
        if (list.size() < 3)
            return;

        list.move(1, 2);
        std::swap(values[1], values[2]);
        REQUIRE(list == values);
        REQUIRE(results == values);

        list.move(2, 1);
        std::swap(values[1], values[2]);
        REQUIRE(list == values);
        REQUIRE(results == values);

        list.move(0, 2);
        std::rotate(values.begin(), values.begin() + 1, values.begin() + 3);
        REQUIRE(list == values);
        REQUIRE(results == values);

        list.move(2, 0);
        std::rotate(values.begin(), values.begin() + 2, values.begin() + 3);
        REQUIRE(list == values);
        REQUIRE(results == values);
    }

    SECTION("remove()") {
        if (list.size() < 3)
            return;

        list.remove(1);
        values.erase(values.begin() + 1);
        REQUIRE(list == values);
        REQUIRE(results == values);
    }

    SECTION("remove_all()") {
        list.remove_all();
        REQUIRE(list.size() == 0);
        REQUIRE(results.size() == 0);
    }

    SECTION("swap()") {
        if (list.size() < 3)
            return;

        list.swap(0, 2);
        std::swap(values[0], values[2]);
        REQUIRE(list == values);
        REQUIRE(results == values);
    }

    SECTION("delete_all()") {
        list.delete_all();
        REQUIRE(list.size() == 0);
        REQUIRE(results.size() == 0);
    }

    SECTION("clear()") {
        results.clear();
        REQUIRE(list.size() == 0);
        REQUIRE(results.size() == 0);
    }

    SECTION("get()") {
        for (size_t i = 0; i < values.size(); ++i) {
            CAPTURE(i);
            REQUIRE(list.get<T>(i) == values[i]);
            REQUIRE(results.get<T>(i) == values[i]);
            REQUIRE(any_cast<Boxed>(list.get(ctx, i)) == Boxed(values[i]));
            REQUIRE(any_cast<Boxed>(results.get(ctx, i)) == Boxed(values[i]));
        }
        REQUIRE_THROWS(list.get<T>(values.size()));
        REQUIRE_THROWS(results.get<T>(values.size()));
        REQUIRE_THROWS(list.get(ctx, values.size()));
        REQUIRE_THROWS(results.get(ctx, values.size()));
    }

    SECTION("first()") {
        REQUIRE(*results.first<T>() == values.front());
        REQUIRE(any_cast<Boxed>(*results.first(ctx)) == Boxed(values.front()));
        list.remove_all();
        REQUIRE(results.first<T>() == util::none);
    }

    SECTION("last()") {
        REQUIRE(*results.last<T>() == values.back());
        list.remove_all();
        REQUIRE(results.last<T>() == util::none);
    }

    SECTION("set()") {
        for (size_t i = 0; i < values.size(); ++i) {
            CAPTURE(i);
            auto rev = values.size() - i - 1;
            list.set(i, static_cast<T>(values[rev]));
            REQUIRE(list.get<T>(i) == values[rev]);
            REQUIRE(results.get<T>(i) == values[rev]);
        }
        for (size_t i = 0; i < values.size(); ++i) {
            CAPTURE(i);
            list.set(ctx, i, TestType::to_any(values[i]));
            REQUIRE(list.get<T>(i) == values[i]);
            REQUIRE(results.get<T>(i) == values[i]);
        }

        REQUIRE_THROWS(list.set(list.size(), static_cast<T>(values[0])));
    }

    SECTION("find()") {
        // cast to T needed for vector<bool>'s wonky proxy
        for (size_t i = 0; i < values.size(); ++i) {
            CAPTURE(i);
            REQUIRE(list.find(static_cast<T>(values[i])) == i);
            REQUIRE(results.index_of(static_cast<T>(values[i])) == i);

            REQUIRE(list.find(ctx, TestType::to_any(values[i])) == i);
            REQUIRE(results.index_of(ctx, TestType::to_any(values[i])) == i);

            auto q = TestType::unwrap(values[i], [&] (auto v) { return table->get_subtable(0, 0)->column<W>(0) == v; });
            REQUIRE(list.find(Query(q)) == i);
            REQUIRE(results.index_of(std::move(q)) == i);
        }

        list.remove(0);
        REQUIRE(list.find(static_cast<T>(values[0])) == npos);
        REQUIRE(results.index_of(static_cast<T>(values[0])) == npos);

        REQUIRE(list.find(ctx, TestType::to_any(values[0])) == npos);
        REQUIRE(results.index_of(ctx, TestType::to_any(values[0])) == npos);
    }

    SECTION("sorted index_of()") {
        auto subtable = table->get_subtable(0, 0);

        auto sorted = list.sort({{"self", true}});
        std::sort(begin(values), end(values), less());
        for (size_t i = 0; i < values.size(); ++i) {
            CAPTURE(i);
            auto q = TestType::unwrap(values[i], [&] (auto v) { return table->get_subtable(0, 0)->column<W>(0) == v; });
            REQUIRE(sorted.index_of(std::move(q)) == i);
        }

        sorted = list.sort({{"self", false}});
        std::sort(begin(values), end(values), greater());
        for (size_t i = 0; i < values.size(); ++i) {
            CAPTURE(i);
            auto q = TestType::unwrap(values[i], [&] (auto v) { return table->get_subtable(0, 0)->column<W>(0) == v; });
            REQUIRE(sorted.index_of(std::move(q)) == i);
        }
    }

    SECTION("filtered index_of()") {
        REQUIRE_THROWS(results.index_of(table->get(0)));
        auto q = TestType::unwrap(values[0], [&] (auto v) { return table->get_subtable(0, 0)->column<W>(0) != v; });
        auto filtered = list.filter(std::move(q));
        for (size_t i = 1; i < values.size(); ++i) {
            CAPTURE(i);
            REQUIRE(filtered.index_of(static_cast<T>(values[i])) == i - 1);
        }
    }

    SECTION("sort()") {
        auto subtable = table->get_subtable(0, 0);

        auto unsorted = list.sort(std::vector<std::pair<std::string, bool>>{});
        REQUIRE(unsorted == values);

        auto sorted = list.sort(SortDescriptor(*subtable, {{0}}, {true}));
        auto sorted2 = list.sort({{"self", true}});
        std::sort(begin(values), end(values), less());
        REQUIRE(sorted == values);
        REQUIRE(sorted2 == values);

        sorted = list.sort(SortDescriptor(*subtable, {{0}}, {false}));
        sorted2 = list.sort({{"self", false}});
        std::sort(begin(values), end(values), greater());
        REQUIRE(sorted == values);
        REQUIRE(sorted2 == values);

        REQUIRE_THROWS_WITH(list.sort({{"not self", true}}),
                            util::format("Cannot sort on key path 'not self': arrays of '%1' can only be sorted on 'self'",
                                         string_for_property_type(TestType::property_type() & ~PropertyType::Flags)));
        REQUIRE_THROWS_WITH(list.sort({{"self", true}, {"self", false}}),
                            util::format("Cannot sort array of '%1' on more than one key path",
                                         string_for_property_type(TestType::property_type() & ~PropertyType::Flags)));
    }

    SECTION("distinct()") {
        for (T value : values)
            list.add(value);
        auto values2 = values;
        values2.insert(values2.end(), values.begin(), values.end());

        auto subtable = table->get_subtable(0, 0);

        auto undistinct = list.as_results().distinct(std::vector<std::string>{});
        REQUIRE(undistinct == values2);

        auto distinct = results.distinct(SortDescriptor(*subtable, {{0}}, {true}));
        auto distinct2 = results.distinct({"self"});
        REQUIRE(distinct == values);
        REQUIRE(distinct2 == values);

        REQUIRE_THROWS_WITH(results.distinct({{"not self"}}),
                            util::format("Cannot sort on key path 'not self': arrays of '%1' can only be sorted on 'self'",
                                         string_for_property_type(TestType::property_type() & ~PropertyType::Flags)));
        REQUIRE_THROWS_WITH(results.distinct({{"self"}, {"self"}}),
                            util::format("Cannot sort array of '%1' on more than one key path",
                                         string_for_property_type(TestType::property_type() & ~PropertyType::Flags)));
    }

    SECTION("filter()") {
        T v = values.front();
        values.erase(values.begin());

        auto q = TestType::unwrap(v, [&] (auto v) { return table->get_subtable(0, 0)->column<W>(0) != v; });
        Results filtered = list.filter(std::move(q));
        REQUIRE(filtered == values);

        q = TestType::unwrap(v, [&] (auto v) { return table->get_subtable(0, 0)->column<W>(0) == v; });
        filtered = list.filter(std::move(q));
        REQUIRE(filtered.size() == 1);
        REQUIRE(*filtered.first<T>() == v);
    }

    SECTION("min()") {
        if (!TestType::can_minmax()) {
            REQUIRE_THROWS(list.min());
            REQUIRE_THROWS(results.min());
            return;
        }

        REQUIRE(get<W>(*list.min()) == TestType::min());
        REQUIRE(get<W>(*results.min()) == TestType::min());
        list.remove_all();
        REQUIRE(list.min() == util::none);
        REQUIRE(results.min() == util::none);
    }

    SECTION("max()") {
        if (!TestType::can_minmax()) {
            REQUIRE_THROWS(list.max());
            REQUIRE_THROWS(results.max());
            return;
        }

        REQUIRE(get<W>(*list.max()) == TestType::max());
        REQUIRE(get<W>(*results.max()) == TestType::max());
        list.remove_all();
        REQUIRE(list.max() == util::none);
        REQUIRE(results.max() == util::none);
    }

    SECTION("sum()") {
        if (!TestType::can_sum()) {
            REQUIRE_THROWS(list.sum());
            return;
        }

        REQUIRE(get<W>(list.sum()) == TestType::sum());
        REQUIRE(get<W>(*results.sum()) == TestType::sum());
        list.remove_all();
        REQUIRE(get<W>(list.sum()) == W{});
        REQUIRE(get<W>(*results.sum()) == W{});
    }

    SECTION("average()") {
        if (!TestType::can_average()) {
            REQUIRE_THROWS(list.average());
            return;
        }

        REQUIRE(*list.average() == TestType::average());
        REQUIRE(*results.average() == TestType::average());
        list.remove_all();
        REQUIRE(list.average() == util::none);
        REQUIRE(results.average() == util::none);
    }

    SECTION("operator==()") {
        table->add_empty_row();
        REQUIRE(list == List(r, *table, 0, 0));
        REQUIRE_FALSE(list == List(r, *table, 0, 1));
    }

    SECTION("hash") {
        table->add_empty_row();
        std::hash<List> h;
        REQUIRE(h(list) == h(List(r, *table, 0, 0)));
        REQUIRE_FALSE(h(list) == h(List(r, *table, 0, 1)));
    }

    SECTION("handover") {
        r->commit_transaction();

        auto handover = r->obtain_thread_safe_reference(list);
        auto list2 = r->resolve_thread_safe_reference(std::move(handover));
        REQUIRE(list == list2);

        auto results_handover = r->obtain_thread_safe_reference(results);
        auto results2 = r->resolve_thread_safe_reference(std::move(results_handover));
        REQUIRE(results2 == values);
    }

    SECTION("notifications") {
        r->commit_transaction();

        CollectionChangeSet change, rchange;
        SECTION("add value to list") {
            auto token = list.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                change = c;
            });
            auto rtoken = results.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                rchange = c;
            });
            advance_and_notify(*r);

            r->begin_transaction();
            list.insert(0, static_cast<T>(values[0]));
            r->commit_transaction();
            advance_and_notify(*r);
            REQUIRE_INDICES(change.insertions, 0);
            REQUIRE_INDICES(rchange.insertions, 0);
        }

        SECTION("clear list") {
            auto token = list.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                change = c;
            });
            auto rtoken = results.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                rchange = c;
            });
            advance_and_notify(*r);

            r->begin_transaction();
            list.remove_all();
            r->commit_transaction();
            advance_and_notify(*r);
            REQUIRE(change.deletions.count() == values.size());
            REQUIRE(rchange.deletions.count() == values.size());
        }

        SECTION("delete containing row") {
            size_t calls = 0;
            auto token = list.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                change = c;
                ++calls;
            });
            auto rtoken = results.add_notification_callback([&](CollectionChangeSet c, std::exception_ptr) {
                rchange = c;
                ++calls;
            });
            advance_and_notify(*r);
            REQUIRE(calls == 2);

            r->begin_transaction();
            table->move_last_over(0);
            r->commit_transaction();
            advance_and_notify(*r);
            REQUIRE(calls == 4);
            REQUIRE(change.deletions.count() == values.size());
            REQUIRE(rchange.deletions.count() == values.size());

            r->begin_transaction();
            table->add_empty_row();
            r->commit_transaction();
            advance_and_notify(*r);
            REQUIRE(calls == 4);
        }
    }

#if REALM_ENABLE_SYNC && REALM_HAVE_SYNC_STABLE_IDS
    SECTION("sync compatibility") {
        if (!util::EventLoop::has_implementation())
            return;

        SyncServer server;
        SyncTestFile sync_config(server, "shared");
        sync_config.schema = config.schema;
        sync_config.schema_version = 0;

        {
            auto r = Realm::get_shared_realm(sync_config);
            r->begin_transaction();

            CppContext ctx(r);
            auto obj = Object::create(ctx, r, *r->schema().find("object"), util::Any(AnyDict{}));
            auto list = any_cast<List>(obj.get_property_value<util::Any>(ctx, "value"));
            list.add(static_cast<T>(values[0]));

            r->commit_transaction();
            wait_for_upload(*r);
        }

        util::File::remove(sync_config.path);

        {
            auto r = Realm::get_shared_realm(sync_config);
            auto table = r->read_group().get_table("class_object");

            util::EventLoop::main().run_until([&] {
                return table->size() == 1;
            });

            CppContext ctx(r);
            Object obj(r, "object", 0);
            auto list = any_cast<List>(obj.get_property_value<util::Any>(ctx, "value"));
            REQUIRE(list.get<T>(0) == values[0]);
        }
    }
#endif
}
