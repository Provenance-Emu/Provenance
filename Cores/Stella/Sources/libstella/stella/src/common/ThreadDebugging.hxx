//============================================================================
//
//   SSSS    tt          lll  lll
//  SS  SS   tt           ll   ll
//  SS     tttttt  eeee   ll   ll   aaaa
//   SSSS    tt   ee  ee  ll   ll      aa
//      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
//  SS  SS   tt   ee      ll   ll  aa  aa
//   SSSS     ttt  eeeee llll llll  aaaaa
//
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef THREADING_DEBUGGER_HXX
#define THREADING_DEBUGGER_HXX

#include <thread>

#include "bspf.hxx"

#ifdef DEBUG_BUILD

#define SET_MAIN_THREAD ThreadDebuggingHelper::instance().setMainThread();
#define ASSERT_MAIN_THREAD ThreadDebuggingHelper::instance().assertMainThread();

#else

#define SET_MAIN_THREAD
#define ASSERT_MAIN_THREAD

#endif

class ThreadDebuggingHelper {

  public:

    void setMainThread();

    void assertMainThread();

    static ThreadDebuggingHelper& instance();

  private:

    [[noreturn]] static void fail(const string& message);

    ThreadDebuggingHelper() = default;

    std::thread::id myMainThreadId;

    bool myMainThreadIdConfigured{false};

  private:

    ThreadDebuggingHelper(const ThreadDebuggingHelper&) = delete;
    ThreadDebuggingHelper(ThreadDebuggingHelper&&) = delete;
    ThreadDebuggingHelper& operator=(const ThreadDebuggingHelper&) = delete;
    ThreadDebuggingHelper& operator=(ThreadDebuggingHelper&&) = delete;
};

#endif // THREADING_DEBUGGER_HXX
