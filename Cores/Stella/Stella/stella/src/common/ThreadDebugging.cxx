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
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#include "ThreadDebugging.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ThreadDebuggingHelper& ThreadDebuggingHelper::instance()
{
  static ThreadDebuggingHelper instance;

  return instance;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ThreadDebuggingHelper::fail(const string& message)
{
  cerr << message << endl;

  throw runtime_error(message);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ThreadDebuggingHelper::setMainThread()
{
  if (myMainThreadIdConfigured) fail("main thread already configured");

  myMainThreadIdConfigured = true;
  myMainThreadId = std::this_thread::get_id();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ThreadDebuggingHelper::assertMainThread()
{
  if (!myMainThreadIdConfigured) fail("main thread not configured");

  if (std::this_thread::get_id() != myMainThreadId) fail("must be called from main thread");
}
