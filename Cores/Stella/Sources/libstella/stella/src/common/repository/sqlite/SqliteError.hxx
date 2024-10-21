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

#ifndef SQLITE_ERROR_HXX
#define SQLITE_ERROR_HXX

#include <sqlite3.h>
#include "bspf.hxx"

class SqliteError : public std::exception
{
  public:
    explicit SqliteError(string_view message) : myMessage{message} { }
    explicit SqliteError(sqlite3* handle) : myMessage{sqlite3_errmsg(handle)} { }

    const char* what() const noexcept override { return myMessage.c_str(); }

  private:
    const string myMessage;
};

#endif // SQLITE_ERROR_HXX
