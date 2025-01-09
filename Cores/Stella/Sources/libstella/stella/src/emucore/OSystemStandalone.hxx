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

#ifndef OSYSTEM_STANDALONE_HXX
#define OSYSTEM_STANDALONE_HXX

#include "OSystem.hxx"

class StellaDb;

class OSystemStandalone : public OSystem
{
  public:

    OSystemStandalone() = default;

    shared_ptr<KeyValueRepository> getSettingsRepository() override;

    shared_ptr<CompositeKeyValueRepository> getPropertyRepository() override;

    shared_ptr<CompositeKeyValueRepositoryAtomic> getHighscoreRepository() override;

  protected:

    void initPersistence(FSNode& basedir) override;

    string describePresistence() override;

    void getBaseDirectories(string& basedir, string& homedir,
                            bool useappdir, string_view usedir) override;

  private:

    shared_ptr<StellaDb> myStellaDb;

};

#endif // OSYSTEM_STANDALONE_HXX
