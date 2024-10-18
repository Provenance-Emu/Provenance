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

#include "StellaDb.hxx"
#include "OSystemStandalone.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OSystemStandalone::initPersistence(FSNode& basedir)
{
  myStellaDb = make_shared<StellaDb>(basedir.getPath(), "stella");
  myStellaDb->initialize();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string OSystemStandalone::describePresistence()
{
  return (myStellaDb && myStellaDb->isValid()) ? myStellaDb->databaseFileName() : "none";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
shared_ptr<KeyValueRepository> OSystemStandalone::getSettingsRepository()
{
  return {myStellaDb, &myStellaDb->settingsRepository()};
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
shared_ptr<CompositeKeyValueRepository> OSystemStandalone::getPropertyRepository()
{
  return {myStellaDb, &myStellaDb->propertyRepository()};
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
shared_ptr<CompositeKeyValueRepositoryAtomic> OSystemStandalone::getHighscoreRepository()
{
  return {myStellaDb, &myStellaDb->highscoreRepository()};
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OSystemStandalone::getBaseDirectories(
    string& basedir, string& homedir, bool useappdir, string_view usedir)
{
}
