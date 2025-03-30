/*
Copyright (c) 2017 Arun Muralidharan

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

#ifndef CPP_JWT_ASSERTIONS_HPP
#define CPP_JWT_ASSERTIONS_HPP

#include <cassert>

namespace jwt {

#if defined(__clang__)
#  define JWT_NOT_REACHED_MARKER() __builtin_unreachable()
#elif defined(__GNUC__)
#  if __GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 5)
#    define JWT_NOT_REACHED_MARKER() __builtin_unreachable()
#  endif
#elif defined(_MSC_VER)
#  define JWT_NOT_REACHED_MARKER() __assume(0)
#endif

#if defined(DEBUG)
#  define JWT_NOT_REACHED(reason)  do { \
                                     assert (0 && reason); \
                                     JWT_NOT_REACHED_MARKER();        \
                                   } while (0)
#else
#  define JWT_NOT_REACHED(reason)  JWT_NOT_REACHED_MARKER()
#endif

} // END namespace jwt

#endif
