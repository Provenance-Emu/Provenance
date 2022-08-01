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

#include "FSNode.hxx"
#include "OSystemLIBRETRO.hxx"
#include "repository/KeyValueRepositoryNoop.hxx"
#include "repository/CompositeKeyValueRepositoryNoop.hxx"

#ifdef _WIN32
  const string slash = "\\";
#else
  const string slash = "/";
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OSystemLIBRETRO::getBaseDirectories(string& basedir, string& homedir,
                                         bool useappdir, const string& usedir)
{
  basedir = homedir = "." + slash;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OSystemLIBRETRO::initPersistence(FSNode& basedir)
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string OSystemLIBRETRO::describePresistence()
{
  return "none";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
shared_ptr<KeyValueRepository> OSystemLIBRETRO::getSettingsRepository()
{
  return make_shared<KeyValueRepositoryNoop>();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
shared_ptr<CompositeKeyValueRepository> OSystemLIBRETRO::getPropertyRepository()
{
  return make_shared<CompositeKeyValueRepositoryNoop>();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
shared_ptr<CompositeKeyValueRepositoryAtomic> OSystemLIBRETRO::getHighscoreRepository()
{
  return make_shared<CompositeKeyValueRepositoryNoop>();
}
