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

#include <cstdlib>

#include "FSNode.hxx"
#include "Version.hxx"
#include "OSystemUNIX.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OSystemUNIX::getBaseDirectories(string& basedir, string& homedir,
                                     bool useappdir, const string& usedir)
{
  // Use XDG_CONFIG_HOME if defined, otherwise use the default
  const char* cfg_home = std::getenv("XDG_CONFIG_HOME");
  const string& configDir = cfg_home != nullptr ? cfg_home : "~/.config";
  basedir = configDir + "/stella";
  homedir = "~/";

  // Check to see if basedir overrides are active
  if(useappdir)
    cout << "ERROR: base dir in app folder not supported" << endl;
  else if(usedir != "")
    basedir = FSNode(usedir).getPath();
}
