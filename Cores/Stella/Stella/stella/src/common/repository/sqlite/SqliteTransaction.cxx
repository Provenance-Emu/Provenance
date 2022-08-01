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

#include "SqliteTransaction.hxx"
#include "SqliteDatabase.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteTransaction::SqliteTransaction(SqliteDatabase& db)
  : myDb{db}
{
  if (sqlite3_get_autocommit(db)) {
    myTransactionClosed = true;
    return;
  }

  myDb.exec("BEGIN TRANSACTION");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SqliteTransaction::~SqliteTransaction()
{
  if (!myTransactionClosed) rollback();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SqliteTransaction::commit()
{
  if (myTransactionClosed) return;

  myTransactionClosed = true;
  myDb.exec("COMMIT TRANSACTION");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void SqliteTransaction::rollback()
{
  if (myTransactionClosed) return;

  myTransactionClosed = true;
  myDb.exec("ROLLBACK TRANSACTION");
}
