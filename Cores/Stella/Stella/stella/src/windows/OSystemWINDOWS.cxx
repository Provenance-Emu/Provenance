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

#include "bspf.hxx"
#include "FSNode.hxx"
#include "HomeFinder.hxx"

#include "OSystemWINDOWS.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void OSystemWINDOWS::getBaseDirectories(string& basedir, string& homedir,
                                        bool useappdir, const string& usedir)
{
  HomeFinder homefinder;
  FSNode appdata(homefinder.getAppDataPath());

  if(appdata.isDirectory())
  {
    basedir = appdata.getShortPath();
    if(basedir.length() > 1 && basedir[basedir.length() - 1] != '\\')
      basedir += '\\';
    basedir += "Stella\\";
  }

  FSNode defaultHomeDir(homefinder.getDesktopPath());
  homedir = defaultHomeDir.getShortPath();

  // Check to see if basedir overrides are active
  if(useappdir)
  {
    char filename[MAX_PATH];
    GetModuleFileNameA(NULL, filename, sizeof(filename));
    FSNode appdir(filename);

    appdir = appdir.getParent();
    if(appdir.isDirectory())
      basedir = appdir.getPath();
  }
  else if(usedir != "")
    basedir = FSNode(usedir).getPath();
}
