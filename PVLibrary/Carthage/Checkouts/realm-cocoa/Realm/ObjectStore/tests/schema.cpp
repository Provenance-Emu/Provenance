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

#include "object_schema.hpp"
#include "object_store.hpp"
#include "property.hpp"
#include "schema.hpp"

#include <realm/descriptor.hpp>
#include <realm/group.hpp>
#include <realm/table.hpp>

using namespace realm;

struct SchemaChangePrinter {
    std::ostream& out;

    template<typename Value>
    void print(Value value) const
    {
        out << value;
    }

    template<typename Value, typename... Rest>
    void print(Value value, Rest... rest) const
    {
        out << value << ", ";
        print(rest...);
    }

#define REALM_SC_PRINT(type, ...) \
    void operator()(schema_change::type v) const \
    { \
        out << #type << "{"; \
        print(__VA_ARGS__); \
        out << "}"; \
    }

    REALM_SC_PRINT(AddIndex, v.object, v.property)
    REALM_SC_PRINT(AddProperty, v.object, v.property)
    REALM_SC_PRINT(AddTable, v.object)
    REALM_SC_PRINT(RemoveTable, v.object)
    REALM_SC_PRINT(AddInitialProperties, v.object)
    REALM_SC_PRINT(ChangePrimaryKey, v.object, v.property)
    REALM_SC_PRINT(ChangePropertyType, v.object, v.old_property, v.new_property)
    REALM_SC_PRINT(MakePropertyNullable, v.object, v.property)
    REALM_SC_PRINT(MakePropertyRequired, v.object, v.property)
    REALM_SC_PRINT(RemoveIndex, v.object, v.property)
    REALM_SC_PRINT(RemoveProperty, v.object, v.property)

#undef REALM_SC_PRINT
};

namespace Catch {
template<>
struct StringMaker<SchemaChange> {
    static std::string convert(SchemaChange const& sc)
    {
        std::stringstream ss;
        sc.visit(SchemaChangePrinter{ss});
        return ss.str();
    }
};
} // namespace Catch

#define REQUIRE_THROWS_CONTAINING(expr, msg) \
    REQUIRE_THROWS_WITH(expr, Catch::Matchers::Contains(msg))

TEST_CASE("ObjectSchema") {
    SECTION("from a Group") {
        Group g;
        TableRef pk = g.add_table("pk");
        pk->add_column(type_String, "pk_table");
        pk->add_column(type_String, "pk_property");
        pk->add_empty_row();
        pk->set_string(0, 0, "table");
        pk->set_string(1, 0, "pk");

        TableRef table = g.add_table("class_table");
        TableRef target = g.add_table("class_target");

        table->add_column(type_Int, "pk");

        table->add_column(type_Int, "int");
        table->add_column(type_Bool, "bool");
        table->add_column(type_Float, "float");
        table->add_column(type_Double, "double");
        table->add_column(type_String, "string");
        table->add_column(type_Binary, "data");
        table->add_column(type_Timestamp, "date");

        table->add_column_link(type_Link, "object", *target);
        table->add_column_link(type_LinkList, "array", *target);

        table->add_column(type_Int, "int?", true);
        table->add_column(type_Bool, "bool?", true);
        table->add_column(type_Float, "float?", true);
        table->add_column(type_Double, "double?", true);
        table->add_column(type_String, "string?", true);
        table->add_column(type_Binary, "data?", true);
        table->add_column(type_Timestamp, "date?", true);

        table->add_column(type_Table, "subtable 1");
        size_t col = table->add_column(type_Table, "subtable 2");
        table->get_subdescriptor(col)->add_column(type_Int, "value");

        auto add_list = [](TableRef table, DataType type, StringData name, bool nullable) {
            size_t col = table->add_column(type_Table, name);
            table->get_subdescriptor(col)->add_column(type, ObjectStore::ArrayColumnName, nullptr, nullable);
        };

        add_list(table, type_Int, "int array", false);
        add_list(table, type_Bool, "bool array", false);
        add_list(table, type_Float, "float array", false);
        add_list(table, type_Double, "double array", false);
        add_list(table, type_String, "string array", false);
        add_list(table, type_Binary, "data array", false);
        add_list(table, type_Timestamp, "date array", false);
        add_list(table, type_Int, "int? array", true);
        add_list(table, type_Bool, "bool? array", true);
        add_list(table, type_Float, "float? array", true);
        add_list(table, type_Double, "double? array", true);
        add_list(table, type_String, "string? array", true);
        add_list(table, type_Binary, "data? array", true);
        add_list(table, type_Timestamp, "date? array", true);

        size_t indexed_start = table->get_column_count();
        table->add_column(type_Int, "indexed int");
        table->add_column(type_Bool, "indexed bool");
        table->add_column(type_String, "indexed string");
        table->add_column(type_Timestamp, "indexed date");

        table->add_column(type_Int, "indexed int?", true);
        table->add_column(type_Bool, "indexed bool?", true);
        table->add_column(type_String, "indexed string?", true);
        table->add_column(type_Timestamp, "indexed date?", true);

        for (size_t i = indexed_start; i < table->get_column_count(); ++i)
            table->add_search_index(i);

        ObjectSchema os(g, "table");

#define REQUIRE_PROPERTY(name, type, ...) do { \
    Property* prop; \
    REQUIRE((prop = os.property_for_name(name))); \
    REQUIRE((*prop == Property{name, PropertyType::type, __VA_ARGS__})); \
    REQUIRE(prop->table_column == expected_col++); \
} while (0)

        size_t expected_col = 0;

        REQUIRE(os.property_for_name("nonexistent property") == nullptr);

        REQUIRE_PROPERTY("pk", Int, Property::IsPrimary{true});

        REQUIRE_PROPERTY("int", Int);
        REQUIRE_PROPERTY("bool", Bool);
        REQUIRE_PROPERTY("float", Float);
        REQUIRE_PROPERTY("double", Double);
        REQUIRE_PROPERTY("string", String);
        REQUIRE_PROPERTY("data", Data);
        REQUIRE_PROPERTY("date", Date);

        REQUIRE_PROPERTY("object", Object|PropertyType::Nullable, "target");
        REQUIRE_PROPERTY("array", Array|PropertyType::Object, "target");

        REQUIRE_PROPERTY("int?", Int|PropertyType::Nullable);
        REQUIRE_PROPERTY("bool?", Bool|PropertyType::Nullable);
        REQUIRE_PROPERTY("float?", Float|PropertyType::Nullable);
        REQUIRE_PROPERTY("double?", Double|PropertyType::Nullable);
        REQUIRE_PROPERTY("string?", String|PropertyType::Nullable);
        REQUIRE_PROPERTY("data?", Data|PropertyType::Nullable);
        REQUIRE_PROPERTY("date?", Date|PropertyType::Nullable);

        // Unsupported column type should be skipped entirely
        REQUIRE(os.property_for_name("subtable 1") == nullptr);
        REQUIRE(os.property_for_name("subtable 2") == nullptr);
        expected_col += 2;

        REQUIRE_PROPERTY("int array", Int|PropertyType::Array);
        REQUIRE_PROPERTY("bool array", Bool|PropertyType::Array);
        REQUIRE_PROPERTY("float array", Float|PropertyType::Array);
        REQUIRE_PROPERTY("double array", Double|PropertyType::Array);
        REQUIRE_PROPERTY("string array", String|PropertyType::Array);
        REQUIRE_PROPERTY("data array", Data|PropertyType::Array);
        REQUIRE_PROPERTY("date array", Date|PropertyType::Array);
        REQUIRE_PROPERTY("int? array", Int|PropertyType::Array|PropertyType::Nullable);
        REQUIRE_PROPERTY("bool? array", Bool|PropertyType::Array|PropertyType::Nullable);
        REQUIRE_PROPERTY("float? array", Float|PropertyType::Array|PropertyType::Nullable);
        REQUIRE_PROPERTY("double? array", Double|PropertyType::Array|PropertyType::Nullable);
        REQUIRE_PROPERTY("string? array", String|PropertyType::Array|PropertyType::Nullable);
        REQUIRE_PROPERTY("data? array", Data|PropertyType::Array|PropertyType::Nullable);
        REQUIRE_PROPERTY("date? array", Date|PropertyType::Array|PropertyType::Nullable);

        REQUIRE_PROPERTY("indexed int", Int, Property::IsPrimary{false}, Property::IsIndexed{true});
        REQUIRE_PROPERTY("indexed bool", Bool, Property::IsPrimary{false}, Property::IsIndexed{true});
        REQUIRE_PROPERTY("indexed string", String, Property::IsPrimary{false}, Property::IsIndexed{true});
        REQUIRE_PROPERTY("indexed date", Date, Property::IsPrimary{false}, Property::IsIndexed{true});

        REQUIRE_PROPERTY("indexed int?", Int|PropertyType::Nullable, Property::IsPrimary{false}, Property::IsIndexed{true});
        REQUIRE_PROPERTY("indexed bool?", Bool|PropertyType::Nullable, Property::IsPrimary{false}, Property::IsIndexed{true});
        REQUIRE_PROPERTY("indexed string?", String|PropertyType::Nullable, Property::IsPrimary{false}, Property::IsIndexed{true});
        REQUIRE_PROPERTY("indexed date?", Date|PropertyType::Nullable, Property::IsPrimary{false}, Property::IsIndexed{true});

        pk->set_string(1, 0, "nonexistent property");
        REQUIRE(ObjectSchema(g, "table").primary_key_property() == nullptr);
    }
}

TEST_CASE("Schema") {
    SECTION("validate()") {
        SECTION("rejects link properties with no target object") {
            Schema schema = {
                {"object", {
                    {"link", PropertyType::Object|PropertyType::Nullable}
                }},
            };
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.link' of type 'object' has unknown object type ''");
        }

        SECTION("rejects array properties with no target object") {
            Schema schema = {
                {"object", {
                    {"array", PropertyType::Array|PropertyType::Object}
                }},
            };
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.array' of type 'array' has unknown object type ''");
        }

        SECTION("rejects link properties with a target not in the schema") {
            Schema schema = {
                {"object", {
                    {"link", PropertyType::Object|PropertyType::Nullable, "invalid target"}
                }}
            };
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.link' of type 'object' has unknown object type 'invalid target'");
        }

        SECTION("rejects array properties with a target not in the schema") {
            Schema schema = {
                {"object", {
                    {"array", PropertyType::Array|PropertyType::Object, "invalid target"}
                }}
            };
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.array' of type 'array' has unknown object type 'invalid target'");
        }

        SECTION("rejects linking objects without a source object") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }, {
                    {"incoming", PropertyType::Array|PropertyType::LinkingObjects, "", ""}
                }}
            };
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.incoming' of type 'linking objects' has unknown object type ''");
        }

        SECTION("rejects linking objects without a source property") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }, {
                    {"incoming", PropertyType::Array|PropertyType::LinkingObjects, "object", ""}
                }}
            };
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.incoming' of type 'linking objects' must have an origin property name.");
        }

        SECTION("rejects linking objects with invalid source object") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }, {
                    {"incoming", PropertyType::Array|PropertyType::LinkingObjects, "not an object type", ""}
                }}
            };
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.incoming' of type 'linking objects' has unknown object type 'not an object type'");
        }

        SECTION("rejects linking objects with invalid source property") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }, {
                    {"incoming", PropertyType::Array|PropertyType::LinkingObjects, "object", "value"}
                }}
            };
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.value' declared as origin of linking objects property 'object.incoming' is not a link");

            schema = {
                {"object", {
                    {"value", PropertyType::Int},
                    {"link", PropertyType::Object|PropertyType::Nullable, "object 2"},
                }, {
                    {"incoming", PropertyType::Array|PropertyType::LinkingObjects, "object", "link"}
                }},
                {"object 2", {
                    {"value", PropertyType::Int},
                }}
            };
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.link' declared as origin of linking objects property 'object.incoming' links to type 'object 2'");

        }

        SECTION("rejects non-array linking objects") {
            Schema schema = {
                {"object", {
                    {"link", PropertyType::Object|PropertyType::Nullable, "object"},
                }, {
                    {"incoming", PropertyType::LinkingObjects, "object", "link"}
                }}
            };
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Linking Objects property 'object.incoming' must be an array.");
        }

        SECTION("rejects target object types for non-link properties") {
            Schema schema = {
                {"object", {
                    {"int", PropertyType::Int},
                    {"bool", PropertyType::Bool},
                    {"float", PropertyType::Float},
                    {"double", PropertyType::Double},
                    {"string", PropertyType::String},
                    {"date", PropertyType::Date},
                }}
            };
            for (auto& prop : schema.begin()->persisted_properties) {
                REQUIRE_NOTHROW(schema.validate());
                prop.object_type = "object";
                REQUIRE_THROWS_CONTAINING(schema.validate(), "cannot have an object type.");
                prop.object_type = "";
            }
        }

        SECTION("rejects source property name for non-linking objects properties") {
            Schema schema = {
                {"object", {
                    {"int", PropertyType::Int},
                    {"bool", PropertyType::Bool},
                    {"float", PropertyType::Float},
                    {"double", PropertyType::Double},
                    {"string", PropertyType::String},
                    {"data", PropertyType::Data},
                    {"date", PropertyType::Date},
                    {"object", PropertyType::Object|PropertyType::Nullable, "object"},
                    {"array", PropertyType::Object|PropertyType::Array, "object"},
                }}
            };
            for (auto& prop : schema.begin()->persisted_properties) {
                REQUIRE_NOTHROW(schema.validate());
                prop.link_origin_property_name = "source";
                auto expected = util::format("Property 'object.%1' of type '%1' cannot have an origin property name.", prop.name, prop.name);
                REQUIRE_THROWS_CONTAINING(schema.validate(), expected);
                prop.link_origin_property_name = "";
            }
        }

        SECTION("rejects non-nullable link properties") {
            Schema schema = {
                {"object", {
                    {"link", PropertyType::Object, "target"}
                }},
                {"target", {
                    {"value", PropertyType::Int}
                }}
            };
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.link' of type 'object' must be nullable.");
        }

        SECTION("rejects nullable array properties") {
            Schema schema = {
                {"object", {
                    {"array", PropertyType::Array|PropertyType::Object|PropertyType::Nullable, "target"}
                }},
                {"target", {
                    {"value", PropertyType::Int}
                }}
            };
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.array' of type 'array' cannot be nullable.");
        }

        SECTION("rejects nullable linking objects") {
            Schema schema = {
                {"object", {
                    {"link", PropertyType::Object|PropertyType::Nullable, "object"},
                }, {
                    {"incoming", PropertyType::LinkingObjects|PropertyType::Array|PropertyType::Nullable, "object", "link"}
                }}
            };
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.incoming' of type 'linking objects' cannot be nullable.");
        }

        SECTION("rejects duplicate primary keys") {
            Schema schema = {
                {"object", {
                    {"pk1", PropertyType::Int, Property::IsPrimary{true}},
                    {"pk2", PropertyType::Int, Property::IsPrimary{true}},
                }}
            };
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Properties 'pk2' and 'pk1' are both marked as the primary key of 'object'.");
        }

        SECTION("rejects invalid primary key types") {
            Schema schema = {
                {"object", {
                    {"pk", PropertyType::Float, Property::IsPrimary{true}},
                }}
            };

            schema.begin()->primary_key_property()->type = PropertyType::Any;
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.pk' of type 'any' cannot be made the primary key.");

            schema.begin()->primary_key_property()->type = PropertyType::Bool;
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.pk' of type 'bool' cannot be made the primary key.");

            schema.begin()->primary_key_property()->type = PropertyType::Float;
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.pk' of type 'float' cannot be made the primary key.");

            schema.begin()->primary_key_property()->type = PropertyType::Double;
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.pk' of type 'double' cannot be made the primary key.");

            schema.begin()->primary_key_property()->type = PropertyType::Object;
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.pk' of type 'object' cannot be made the primary key.");

            schema.begin()->primary_key_property()->type = PropertyType::LinkingObjects;
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.pk' of type 'linking objects' cannot be made the primary key.");

            schema.begin()->primary_key_property()->type = PropertyType::Data;
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.pk' of type 'data' cannot be made the primary key.");

            schema.begin()->primary_key_property()->type = PropertyType::Date;
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Property 'object.pk' of type 'date' cannot be made the primary key.");
        }

        SECTION("allows valid primary key types") {
            Schema schema = {
                {"object", {
                    {"pk", PropertyType::Int, Property::IsPrimary{true}},
                }}
            };

            REQUIRE_NOTHROW(schema.validate());

            schema.begin()->primary_key_property()->type = PropertyType::Int|PropertyType::Nullable;
            REQUIRE_NOTHROW(schema.validate());
            schema.begin()->primary_key_property()->type = PropertyType::String;
            REQUIRE_NOTHROW(schema.validate());
            schema.begin()->primary_key_property()->type = PropertyType::String|PropertyType::Nullable;
            REQUIRE_NOTHROW(schema.validate());
        }

        SECTION("rejects nonexistent primary key") {
            Schema schema = {
                {"object", {
                    {"value", PropertyType::Int},
                }}
            };
            schema.begin()->primary_key = "nonexistent";
            REQUIRE_THROWS_CONTAINING(schema.validate(), "Specified primary key 'object.nonexistent' does not exist.");
        }

        SECTION("rejects indexes for types that cannot be indexed") {
            Schema schema = {
                {"object", {
                    {"float", PropertyType::Float},
                    {"double", PropertyType::Double},
                    {"data", PropertyType::Data},
                    {"object", PropertyType::Object|PropertyType::Nullable, "object"},
                    {"array", PropertyType::Array|PropertyType::Object, "object"},
                }}
            };
            for (auto& prop : schema.begin()->persisted_properties) {
                REQUIRE_NOTHROW(schema.validate());
                prop.is_indexed = true;
                auto expected = util::format("Property 'object.%1' of type '%1' cannot be indexed.", prop.name);
                REQUIRE_THROWS_CONTAINING(schema.validate(), expected);
                prop.is_indexed = false;
            }
        }

        SECTION("allows indexing types that can be indexed") {
            Schema schema = {
                {"object", {
                    {"int", PropertyType::Int, Property::IsPrimary{false}, Property::IsIndexed{true}},
                    {"bool", PropertyType::Bool, Property::IsPrimary{false}, Property::IsIndexed{true}},
                    {"string", PropertyType::String, Property::IsPrimary{false}, Property::IsIndexed{true}},
                    {"date", PropertyType::Date, Property::IsPrimary{false}, Property::IsIndexed{true}},
                }}
            };
            REQUIRE_NOTHROW(schema.validate());
        }

        SECTION("rejects duplicate types with the same name") {
            Schema schema = {
                {"object1", {
                    {"int", PropertyType::Int},
                }},
                {"object2", {
                    {"int", PropertyType::Int},
                }},
                {"object3", {
                    {"int", PropertyType::Int},
                }},
                {"object2", {
                    {"int", PropertyType::Int},
                }},
                {"object1", {
                    {"int", PropertyType::Int},
                }}
            };

            REQUIRE_THROWS_CONTAINING(schema.validate(),
                "- Type 'object1' appears more than once in the schema.\n"
                "- Type 'object2' appears more than once in the schema.");
        }
    }

    SECTION("compare()") {
        using namespace schema_change;
        using vec = std::vector<SchemaChange>;
        SECTION("add table") {
            Schema schema1 = {
                {"object 1", {
                    {"int", PropertyType::Int},
                }}
            };
            Schema schema2 = {
                {"object 1", {
                    {"int", PropertyType::Int},
                }},
                {"object 2", {
                    {"int", PropertyType::Int},
                }}
            };
            auto obj = &*schema2.find("object 2");
            auto expected = vec{AddTable{obj}, AddInitialProperties{obj}};
            REQUIRE(schema1.compare(schema2) == expected);
        }

        SECTION("add property") {
            Schema schema1 = {
                {"object", {
                    {"int 1", PropertyType::Int},
                }}
            };
            Schema schema2 = {
                {"object", {
                    {"int 1", PropertyType::Int},
                    {"int 2", PropertyType::Int},
                }}
            };
            REQUIRE(schema1.compare(schema2) == vec{(AddProperty{&*schema1.find("object"), &schema2.find("object")->persisted_properties[1]})});
        }

        SECTION("remove property") {
            Schema schema1 = {
                {"object", {
                    {"int 1", PropertyType::Int},
                    {"int 2", PropertyType::Int},
                }}
            };
            Schema schema2 = {
                {"object", {
                    {"int 1", PropertyType::Int},
                }}
            };
            REQUIRE(schema1.compare(schema2) == vec{(RemoveProperty{&*schema1.find("object"), &schema1.find("object")->persisted_properties[1]})});
        }

        SECTION("change property type") {
            Schema schema1 = {
                {"object", {
                    {"value", PropertyType::Int},
                }}
            };
            Schema schema2 = {
                {"object", {
                    {"value", PropertyType::Double},
                }}
            };
            REQUIRE(schema1.compare(schema2) == vec{(ChangePropertyType{
                &*schema1.find("object"),
                &schema1.find("object")->persisted_properties[0],
                &schema2.find("object")->persisted_properties[0]})});
        };

        SECTION("change link target") {
            Schema schema1 = {
                {"object", {
                    {"value", PropertyType::Object, "target 1"},
                }},
                {"target 1", {
                    {"value", PropertyType::Int},
                }},
                {"target 2", {
                    {"value", PropertyType::Int},
                }},
            };
            Schema schema2 = {
                {"object", {
                    {"value", PropertyType::Object, "target 2"},
                }},
                {"target 1", {
                    {"value", PropertyType::Int},
                }},
                {"target 2", {
                    {"value", PropertyType::Int},
                }},
            };
            REQUIRE(schema1.compare(schema2) == vec{(ChangePropertyType{
                &*schema1.find("object"),
                &schema1.find("object")->persisted_properties[0],
                &schema2.find("object")->persisted_properties[0]})});
        }

        SECTION("add index") {
            Schema schema1 = {
                {"object", {
                    {"int", PropertyType::Int},
                }}
            };
            Schema schema2 = {
                {"object", {
                    {"int", PropertyType::Int, Property::IsPrimary{false}, Property::IsIndexed{true}},
                }}
            };
            auto object_schema = &*schema1.find("object");
            REQUIRE(schema1.compare(schema2) == vec{(AddIndex{object_schema, &object_schema->persisted_properties[0]})});
        }

        SECTION("remove index") {
            Schema schema1 = {
                {"object", {
                    {"int", PropertyType::Int, Property::IsPrimary{false}, Property::IsIndexed{true}},
                }}
            };
            Schema schema2 = {
                {"object", {
                    {"int", PropertyType::Int},
                }}
            };
            auto object_schema = &*schema1.find("object");
            REQUIRE(schema1.compare(schema2) == vec{(RemoveIndex{object_schema, &object_schema->persisted_properties[0]})});
        }

        SECTION("add index and make nullable") {
            Schema schema1 = {
                {"object", {
                    {"int", PropertyType::Int},
                }}
            };
            Schema schema2 = {
                {"object", {
                    {"int", PropertyType::Int|PropertyType::Nullable, Property::IsPrimary{false}, Property::IsIndexed{true}},
                }}
            };
            auto object_schema = &*schema1.find("object");
            REQUIRE(schema1.compare(schema2) == (vec{
                MakePropertyNullable{object_schema, &object_schema->persisted_properties[0]},
                AddIndex{object_schema, &object_schema->persisted_properties[0]}}));
        }

        SECTION("add index and change type") {
            Schema schema1 = {
                {"object", {
                    {"value", PropertyType::Int},
                }}
            };
            Schema schema2 = {
                {"object", {
                    {"value", PropertyType::Double, Property::IsPrimary{false}, Property::IsIndexed{true}},
                }}
            };
            REQUIRE(schema1.compare(schema2) == vec{(ChangePropertyType{
                &*schema1.find("object"),
                &schema1.find("object")->persisted_properties[0],
                &schema2.find("object")->persisted_properties[0]})});
        }

        SECTION("make nullable and change type") {
            Schema schema1 = {
                {"object", {
                    {"value", PropertyType::Int},
                }}
            };
            Schema schema2 = {
                {"object", {
                    {"value", PropertyType::Double|PropertyType::Nullable},
                }}
            };
            REQUIRE(schema1.compare(schema2) == vec{(ChangePropertyType{
                &*schema1.find("object"),
                &schema1.find("object")->persisted_properties[0],
                &schema2.find("object")->persisted_properties[0]})});
        }
    }
}
