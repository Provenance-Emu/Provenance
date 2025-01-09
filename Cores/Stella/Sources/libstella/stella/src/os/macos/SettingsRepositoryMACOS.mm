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

#import <Cocoa/Cocoa.h>

#include "SettingsRepositoryMACOS.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
KVRMap SettingsRepositoryMACOS::load()
{
  KVRMap values;

  @autoreleasepool {
    NSString* bundleId = [[NSBundle mainBundle] bundleIdentifier];
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSArray* keys = [[defaults persistentDomainForName:bundleId] allKeys];

    for (NSString* key in keys) {
      NSString* value = [defaults stringForKey:key];
      if (value != nil)
        values[[key UTF8String]] = string([value UTF8String]);
    }
  }

  return values;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SettingsRepositoryMACOS::save(const KVRMap& values)
{
  @autoreleasepool {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

    for (const auto& [key, value]: values)
      [defaults
        setObject:[NSString stringWithUTF8String:value.toCString()]
        forKey:[NSString stringWithUTF8String:key.c_str()]
      ];
  }

  return true;
}

