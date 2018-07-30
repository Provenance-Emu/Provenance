/*
 *  Created by Phil on 08/11/2010.
 *  Copyright 2010 Two Blue Cubes Ltd. All rights reserved.
 *
 *  Distributed under the Boost Software License, Version 1.0. (See accompanying
 *  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
 */
#ifdef __clang__
#   pragma clang diagnostic ignored "-Wpadded"
#   pragma clang diagnostic ignored "-Wc++98-compat"
#endif

#include "catch.hpp"

#include <string>
#include <limits>

struct TestData {
    TestData()
    :   int_seven( 7 ),
        str_hello( "hello" ),
        float_nine_point_one( 9.1f ),
        double_pi( 3.1415926535 )
    {}

    int int_seven;
    std::string str_hello;
    float float_nine_point_one;
    double double_pi;
};


struct TestDef {
    TestDef& operator + ( const std::string& ) {
        return *this;
    }
    TestDef& operator[]( const std::string& ) {
        return *this;
    }

};

// The "failing" tests all use the CHECK macro, which continues if the specific test fails.
// This allows us to see all results, even if an earlier check fails

// Equality tests
TEST_CASE( "Equality checks that should succeed", "" )
{

    TestDef td;
    td + "hello" + "hello";

    TestData data;

    REQUIRE( data.int_seven == 7 );
    REQUIRE( data.float_nine_point_one == Approx( 9.1f ) );
    REQUIRE( data.double_pi == Approx( 3.1415926535 ) );
    REQUIRE( data.str_hello == "hello" );
    REQUIRE( "hello" == data.str_hello );
    REQUIRE( data.str_hello.size() == 5 );

    double x = 1.1 + 0.1 + 0.1;
    REQUIRE( x == Approx( 1.3 ) );
}

TEST_CASE( "Equality checks that should fail", "[.][failing][!mayfail]" )
{
    TestData data;

    CHECK( data.int_seven == 6 );
    CHECK( data.int_seven == 8 );
    CHECK( data.int_seven == 0 );
    CHECK( data.float_nine_point_one == Approx( 9.11f ) );
    CHECK( data.float_nine_point_one == Approx( 9.0f ) );
    CHECK( data.float_nine_point_one == Approx( 1 ) );
    CHECK( data.float_nine_point_one == Approx( 0 ) );
    CHECK( data.double_pi == Approx( 3.1415 ) );
    CHECK( data.str_hello == "goodbye" );
    CHECK( data.str_hello == "hell" );
    CHECK( data.str_hello == "hello1" );
    CHECK( data.str_hello.size() == 6 );

    double x = 1.1 + 0.1 + 0.1;
    CHECK( x == Approx( 1.301 ) );
}

TEST_CASE( "Inequality checks that should succeed", "" )
{
    TestData data;

    REQUIRE( data.int_seven != 6 );
    REQUIRE( data.int_seven != 8 );
    REQUIRE( data.float_nine_point_one != Approx( 9.11f ) );
    REQUIRE( data.float_nine_point_one != Approx( 9.0f ) );
    REQUIRE( data.float_nine_point_one != Approx( 1 ) );
    REQUIRE( data.float_nine_point_one != Approx( 0 ) );
    REQUIRE( data.double_pi != Approx( 3.1415 ) );
    REQUIRE( data.str_hello != "goodbye" );
    REQUIRE( data.str_hello != "hell" );
    REQUIRE( data.str_hello != "hello1" );
    REQUIRE( data.str_hello.size() != 6 );
}

TEST_CASE( "Inequality checks that should fail", "[.][failing][!shouldfail]" )
{
    TestData data;

    CHECK( data.int_seven != 7 );
    CHECK( data.float_nine_point_one != Approx( 9.1f ) );
    CHECK( data.double_pi != Approx( 3.1415926535 ) );
    CHECK( data.str_hello != "hello" );
    CHECK( data.str_hello.size() != 5 );
}

// Ordering comparison tests
TEST_CASE( "Ordering comparison checks that should succeed", "" )
{
    TestData data;

    REQUIRE( data.int_seven < 8 );
    REQUIRE( data.int_seven > 6 );
    REQUIRE( data.int_seven > 0 );
    REQUIRE( data.int_seven > -1 );

    REQUIRE( data.int_seven >= 7 );
    REQUIRE( data.int_seven >= 6 );
    REQUIRE( data.int_seven <= 7 );
    REQUIRE( data.int_seven <= 8 );

    REQUIRE( data.float_nine_point_one > 9 );
    REQUIRE( data.float_nine_point_one < 10 );
    REQUIRE( data.float_nine_point_one < 9.2 );

    REQUIRE( data.str_hello <= "hello" );
    REQUIRE( data.str_hello >= "hello" );

    REQUIRE( data.str_hello < "hellp" );
    REQUIRE( data.str_hello < "zebra" );
    REQUIRE( data.str_hello > "hellm" );
    REQUIRE( data.str_hello > "a" );
}

TEST_CASE( "Ordering comparison checks that should fail", "[.][failing]" )
{
    TestData data;

    CHECK( data.int_seven > 7 );
    CHECK( data.int_seven < 7 );
    CHECK( data.int_seven > 8 );
    CHECK( data.int_seven < 6 );
    CHECK( data.int_seven < 0 );
    CHECK( data.int_seven < -1 );

    CHECK( data.int_seven >= 8 );
    CHECK( data.int_seven <= 6 );

    CHECK( data.float_nine_point_one < 9 );
    CHECK( data.float_nine_point_one > 10 );
    CHECK( data.float_nine_point_one > 9.2 );

    CHECK( data.str_hello > "hello" );
    CHECK( data.str_hello < "hello" );
    CHECK( data.str_hello > "hellp" );
    CHECK( data.str_hello > "z" );
    CHECK( data.str_hello < "hellm" );
    CHECK( data.str_hello < "a" );

    CHECK( data.str_hello >= "z" );
    CHECK( data.str_hello <= "a" );
}

// Comparisons with int literals
TEST_CASE( "Comparisons with int literals don't warn when mixing signed/ unsigned", "" )
{
    int i = 1;
    unsigned int ui = 2;
    long l = 3;
    unsigned long ul = 4;
    char c = 5;
    unsigned char uc = 6;

    REQUIRE( i == 1 );
    REQUIRE( ui == 2 );
    REQUIRE( l == 3 );
    REQUIRE( ul == 4 );
    REQUIRE( c == 5 );
    REQUIRE( uc == 6 );

    REQUIRE( 1 == i );
    REQUIRE( 2 == ui );
    REQUIRE( 3 == l );
    REQUIRE( 4 == ul );
    REQUIRE( 5 == c );
    REQUIRE( 6 == uc );

    REQUIRE( (std::numeric_limits<unsigned long>::max)() > ul );
}

// Disable warnings about sign conversions for the next two tests
// (as we are deliberately invoking them)
// - Currently only disabled for GCC/ LLVM. Should add VC++ too
#ifdef  __GNUC__
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wsign-compare"
#pragma GCC diagnostic ignored "-Wsign-conversion"
#endif
#ifdef _MSC_VER
#pragma warning(disable:4389) // '==' : signed/unsigned mismatch
#endif

TEST_CASE( "comparisons between int variables", "" )
{
    long            long_var = 1L;
    unsigned char    unsigned_char_var = 1;
    unsigned short    unsigned_short_var = 1;
    unsigned int    unsigned_int_var = 1;
    unsigned long    unsigned_long_var = 1L;

    REQUIRE( long_var == unsigned_char_var );
    REQUIRE( long_var == unsigned_short_var );
    REQUIRE( long_var == unsigned_int_var );
    REQUIRE( long_var == unsigned_long_var );
}

TEST_CASE( "comparisons between const int variables", "" )
{
    const unsigned char     unsigned_char_var = 1;
    const unsigned short    unsigned_short_var = 1;
    const unsigned int      unsigned_int_var = 1;
    const unsigned long     unsigned_long_var = 1L;

    REQUIRE( unsigned_char_var == 1 );
    REQUIRE( unsigned_short_var == 1 );
    REQUIRE( unsigned_int_var == 1 );
    REQUIRE( unsigned_long_var == 1 );
}

TEST_CASE( "Comparisons between unsigned ints and negative signed ints match c++ standard behaviour", "" )
{
    CHECK( ( -1 > 2u ) );
    CHECK( -1 > 2u );

    CHECK( ( 2u < -1 ) );
    CHECK( 2u < -1 );

    const int minInt = (std::numeric_limits<int>::min)();
    CHECK( ( minInt > 2u ) );
    CHECK( minInt > 2u );
}

TEST_CASE( "Comparisons between ints where one side is computed", "" )
{
     CHECK( 54 == 6*9 );
}

#ifdef  __GNUC__
#pragma GCC diagnostic pop
#endif

inline const char* returnsConstNull(){ return CATCH_NULL; }
inline char* returnsNull(){ return CATCH_NULL; }

TEST_CASE( "Pointers can be compared to null", "" )
{
    TestData* p = CATCH_NULL;
    TestData* pNULL = CATCH_NULL;

    REQUIRE( p == CATCH_NULL );
    REQUIRE( p == pNULL );

    TestData data;
    p = &data;

    REQUIRE( p != CATCH_NULL );

    const TestData* cp = p;
    REQUIRE( cp != CATCH_NULL );

    const TestData* const cpc = p;
    REQUIRE( cpc != CATCH_NULL );

    REQUIRE( returnsNull() == CATCH_NULL );
    REQUIRE( returnsConstNull() == CATCH_NULL );

    REQUIRE( CATCH_NULL != p );
}

// Not (!) tests
// The problem with the ! operator is that it has right-to-left associativity.
// This means we can't isolate it when we decompose. The simple REQUIRE( !false ) form, therefore,
// cannot have the operand value extracted. The test will work correctly, and the situation
// is detected and a warning issued.
// An alternative form of the macros (CHECK_FALSE and REQUIRE_FALSE) can be used instead to capture
// the operand value.
TEST_CASE( "'Not' checks that should succeed", "" )
{
    bool falseValue = false;

    REQUIRE( false == false );
    REQUIRE( true == true );
    REQUIRE( !false );
    REQUIRE_FALSE( false );

    REQUIRE( !falseValue );
    REQUIRE_FALSE( falseValue );

    REQUIRE( !(1 == 2) );
    REQUIRE_FALSE( 1 == 2 );
}

TEST_CASE( "'Not' checks that should fail", "[.][failing]" )
{
    bool trueValue = true;

    CHECK( false != false );
    CHECK( true != true );
    CHECK( !true );
    CHECK_FALSE( true );

    CHECK( !trueValue );
    CHECK_FALSE( trueValue );

    CHECK( !(1 == 1) );
    CHECK_FALSE( 1 == 1 );
}

