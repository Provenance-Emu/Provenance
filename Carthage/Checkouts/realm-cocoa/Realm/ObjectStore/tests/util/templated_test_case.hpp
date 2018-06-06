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

// Work around a msvc preprocessor bug that considers __VA_ARGS__ a single token
// by forcing another round of macro expansion whereever it's used.
#define REALM_EXPAND(x) x

// Define a Catch test case templated on up to 20 types
// The current type is exposed inside the test as `TestType`
#define TEMPLATE_TEST_CASE(name, ...) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE(name, INTERNAL_CATCH_UNIQUE_NAME(REALM_TEMPLATE_TEST_), \
                                          __VA_ARGS__, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1))

#define REALM_TEMPLATE_TEST_CASE(name, fn, T0, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, n, ...) \
    template<typename> static void fn(); \
    TEST_CASE(name) { \
        REALM_TEMPLATE_TEST_CASE_##n(fn, T0, T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19) \
    } \
    template<typename TestType> static void fn()

#define REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    INTERNAL_CATCH_SECTION(#T, "") { fn<T>(); }

#define REALM_TEMPLATE_TEST_CASE_1(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \

#define REALM_TEMPLATE_TEST_CASE_2(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_1(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_3(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_2(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_4(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_3(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_5(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_4(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_6(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_5(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_7(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_6(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_8(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_7(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_9(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_8(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_10(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_9(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_11(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_10(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_12(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_11(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_13(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_12(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_14(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_13(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_15(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_14(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_16(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_15(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_17(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_16(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_18(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_17(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_19(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_18(fn, __VA_ARGS__))

#define REALM_TEMPLATE_TEST_CASE_20(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_19(fn, __VA_ARGS__))

/* // code to generate the above
count = 20

template = r'''
#define REALM_EXPAND(x) x
#define TEMPLATE_TEST_CASE(name, ...) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE(name, INTERNAL_CATCH_UNIQUE_NAME(REALM_TEMPLATE_TEST_), \
                                          __VA_ARGS__, {0}))

#define REALM_TEMPLATE_TEST_CASE(name, fn, {1}, n, ...) \
    template<typename> static void fn(); \
    TEST_CASE(name) {{ \
        REALM_TEMPLATE_TEST_CASE_##n(fn, {1}) \
    }} \
    template<typename TestType> static void fn()

#define REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    INTERNAL_CATCH_SECTION(#T, "") {{ fn<T>(); }}

#define REALM_TEMPLATE_TEST_CASE_1(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
'''

test_case = r'''
#define REALM_TEMPLATE_TEST_CASE_{0}(fn, T, ...) \
    REALM_TEMPLATE_TEST_CASE_SECTION(fn, T) \
    REALM_EXPAND(REALM_TEMPLATE_TEST_CASE_{1}(fn, __VA_ARGS__))
'''

print template.format(', '.join(map(str, reversed(range(count)))),
                      ', '.join(('T' + str(x) for x in range(count)))),

for i in range(1, count):
    print test_case.format(i + 1, i),
*/

