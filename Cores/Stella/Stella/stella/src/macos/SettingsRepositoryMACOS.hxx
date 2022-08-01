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

#ifndef SETTINGS_REPOSITORY_MACOS_HXX
#define SETTINGS_REPOSITORY_MACOS_HXX

#include "repository/KeyValueRepository.hxx"

class SettingsRepositoryMACOS : public KeyValueRepository
{
  public:
    std::map<string, Variant> load() override;

    bool save(const std::map<string, Variant>& values) override;
};

#endif // SETTINGS_REPOSITORY_MACOS_HXX
