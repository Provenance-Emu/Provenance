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

#ifndef __HOME_FINDER_
#define __HOME_FINDER_

#pragma warning( disable : 4091 )
#include <shlobj.h>

/*
 * Used to determine the location of the various Win32 user/system folders.
 */
class HomeFinder
{
  public:
    HomeFinder() = default;
    ~HomeFinder() = default;

    // Return the 'APPDATA' folder, or an empty string if the folder couldn't be determined.
    static const string& getAppDataPath()
    {
      if(ourAppDataPath == "")
      {
        char folder_path[MAX_PATH];
        HRESULT const result = SHGetFolderPathA(NULL, CSIDL_APPDATA | CSIDL_FLAG_CREATE,
          NULL, 0, folder_path);
        ourAppDataPath = (result == S_OK) ? folder_path : EmptyString;
      }
      return ourAppDataPath;
    }

    // Return the 'Desktop' folder, or an empty string if the folder couldn't be determined.
    static const string& getDesktopPath()
    {
      if(ourDesktopPath == "")
      {
        char folder_path[MAX_PATH];
        HRESULT const result = SHGetFolderPathA(NULL, CSIDL_DESKTOPDIRECTORY | CSIDL_FLAG_CREATE,
          NULL, 0, folder_path);
        ourDesktopPath = (result == S_OK) ? folder_path : EmptyString;
      }
      return ourDesktopPath;
    }

    // Return the 'My Documents' folder, or an empty string if the folder couldn't be determined.
    static const string& getDocumentsPath()
    {
      if(ourDocumentsPath == "")
      {
        char folder_path[MAX_PATH];
        HRESULT const result = SHGetFolderPathA(NULL, CSIDL_MYDOCUMENTS | CSIDL_FLAG_CREATE,
          NULL, 0, folder_path);
        ourDocumentsPath = (result == S_OK) ? folder_path : EmptyString;
      }
      return ourDocumentsPath;
    }

    // Return the 'HOME/User' folder, or an empty string if the folder couldn't be determined.
    static const string& getHomePath()
    {
      if(ourHomePath == "")
      {
        char folder_path[MAX_PATH];
        HRESULT const result = SHGetFolderPathA(NULL, CSIDL_PROFILE | CSIDL_FLAG_CREATE,
          NULL, 0, folder_path);
        ourHomePath = (result == S_OK) ? folder_path : EmptyString;
      }
      return ourHomePath;
    }

  private:
    static string ourHomePath, ourAppDataPath, ourDesktopPath, ourDocumentsPath;

    // Following constructors and assignment operators not supported
    HomeFinder(const HomeFinder&) = delete;
    HomeFinder(HomeFinder&&) = delete;
    HomeFinder& operator=(const HomeFinder&) = delete;
    HomeFinder& operator=(HomeFinder&&) = delete;
};

__declspec(selectany) string HomeFinder::ourHomePath = "";
__declspec(selectany) string HomeFinder::ourAppDataPath = "";
__declspec(selectany) string HomeFinder::ourDesktopPath = "";
__declspec(selectany) string HomeFinder::ourDocumentsPath = "";

#endif
