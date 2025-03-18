/*
  Copyright (c) 2018 Arun Muralidharan

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
*/
#ifndef CPP_JWT_CONFIG_HPP
#define CPP_JWT_CONFIG_HPP

#ifdef _MSC_VER 
#define strncasecmp _strnicmp
#define strcasecmp _stricmp
#endif

// To hack around Visual Studio error:
// error C3431: 'algorithm': a scoped enumeration cannot be redeclared as an unscoped enumeration
#if defined(_MSC_VER) && !defined(__clang__)
#define SCOPED_ENUM enum class
#else
#define SCOPED_ENUM enum
#endif

// To hack around Visual Studio error
//  error C3249: illegal statement or sub-expression for 'constexpr' function
//  Doesn't allow assert to be part of constexpr functions.
//  Copied the solution as described in:
//  https://akrzemi1.wordpress.com/2017/05/18/asserts-in-constexpr-functions/
#if defined NDEBUG
# define X_ASSERT(CHECK) void(0)
#else
# define X_ASSERT(CHECK) \
    ( (CHECK) ? void(0) : []{assert(!#CHECK);}() )
#endif


#endif
