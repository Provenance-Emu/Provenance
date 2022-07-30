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

#ifndef SETTINGS_R77_HXX
#define SETTINGS_R77_HXX

#include "Settings.hxx"

/**
  This class is used for the Retron77 system specific settings.
￼	  The Retron77 system is based on an embedded Linux platform.

  @author  Stephen Anthony
*/
class SettingsR77 : public Settings
{
  public:
    /**
      Create a new UNIX settings object
    */
    explicit SettingsR77();
    ~SettingsR77() override = default;

  private:
    // Following constructors and assignment operators not supported
    SettingsR77(const SettingsR77&) = delete;
    SettingsR77(SettingsR77&&) = delete;
    SettingsR77& operator=(const SettingsR77&) = delete;
    SettingsR77& operator=(SettingsR77&&) = delete;
};

#endif
