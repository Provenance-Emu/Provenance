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

#ifndef OSYSTEM_LIBRETRO_HXX
#define OSYSTEM_LIBRETRO_HXX

#include "FSNode.hxx"
#include "OSystem.hxx"
#include "OSystemLIBRETRO.hxx"
#include "repository/KeyValueRepositoryNoop.hxx"
#include "repository/CompositeKeyValueRepositoryNoop.hxx"

#ifdef _WIN32
  const string SLASH = "\\";
#else
  const string SLASH = "/";
#endif

/**
  This class defines an OSystem object for libretro.
  It is responsible for completely implementing getBaseDirectories(),
  to set the base directory and various other save/load locations.

  @author  Stephen Anthony
*/
class OSystemLIBRETRO : public OSystem
{
  public:
    OSystemLIBRETRO() = default;
    ~OSystemLIBRETRO() override = default;

    /**
      Determine the base directory and home directory from the derived
      class.  It can also use hints, as described below.

      @param basedir  The base directory for all configuration files
      @param homedir  The default directory to store various other files
      @param useappdir  A hint that the base dir should be set to the
                        app directory; not all ports can do this, so
                        they are free to ignore it
      @param usedir     A hint that the base dir should be set to this
                        parameter; not all ports can do this, so
                        they are free to ignore it
    */
    void getBaseDirectories(string& basedir, string& homedir,
                            bool useappdir, string_view usedir) override
    {
      basedir = homedir = "." + SLASH;
    }

    shared_ptr<KeyValueRepository>
    getSettingsRepository() override {
      return make_shared<KeyValueRepositoryNoop>();
    }

    shared_ptr<CompositeKeyValueRepository>
    getPropertyRepository() override {
      return make_shared<CompositeKeyValueRepositoryNoop>();
    }

    shared_ptr<CompositeKeyValueRepositoryAtomic>
    getHighscoreRepository() override {
      return make_shared<CompositeKeyValueRepositoryNoop>();
    }

  protected:
    void initPersistence(FSNode& basedir) override { }
    string describePresistence() override { return "none"; }
};

#endif
