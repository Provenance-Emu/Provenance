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

#include <cassert>
#pragma warning( disable : 4091 )
#include <shlobj.h>
#include <io.h>
#include <stdio.h>

// F_OK, R_OK and W_OK are not defined under MSVC, so we define them here
// For more information on the modes used by MSVC, check:
// http://msdn2.microsoft.com/en-us/library/1w06ktdy(VS.80).aspx
#ifndef F_OK
  #define F_OK 0
#endif

#ifndef R_OK
  #define R_OK 4
#endif

#ifndef W_OK
  #define W_OK 2
#endif

#include "Windows.hxx"
#include "FSNodeWINDOWS.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodeWINDOWS::exists() const
{
  return _access(_path.c_str(), F_OK) == 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodeWINDOWS::isReadable() const
{
  return _access(_path.c_str(), R_OK) == 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodeWINDOWS::isWritable() const
{
  return _access(_path.c_str(), W_OK) == 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FSNodeWINDOWS::setFlags()
{
  // Get absolute path
  TCHAR buf[4096];
  if(GetFullPathName(_path.c_str(), 4096, buf, NULL))
    _path = buf;

  _displayName = lastPathComponent(_path);

  // Check whether it is a directory, and whether the file actually exists
  const DWORD fileAttribs = GetFileAttributes(toUnicode(_path.c_str()));

  if(fileAttribs == INVALID_FILE_ATTRIBUTES)
  {
    _isDirectory = _isFile = _isValid = false;
  }
  else
  {
    _isDirectory = ((fileAttribs & FILE_ATTRIBUTE_DIRECTORY) != 0);
    _isFile = !_isDirectory;//((fileAttribs & FILE_ATTRIBUTE_NORMAL) != 0);
    _isValid = true;

    // Add a trailing backslash, if necessary
    if (_isDirectory && _path.length() > 0 && _path[_path.length()-1] != '\\')
      _path += '\\';
  }
  _isPseudoRoot = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FSNodeWINDOWS::addFile(AbstractFSList& list, ListMode mode,
                                    const char* base, WIN32_FIND_DATA* find_data)
{
  FSNodeWINDOWS entry;
  const char* const asciiName = toAscii(find_data->cFileName);
  bool isDirectory = false, isFile = false;

  // Skip local directory (.) and parent (..)
  if(!strncmp(asciiName, ".", 1) || !strncmp(asciiName, "..", 2))
    return;

  isDirectory = ((find_data->dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ? true : false);
  isFile = !isDirectory;//(find_data->dwFileAttributes & FILE_ATTRIBUTE_NORMAL ? true : false);

  if((isFile && mode == FSNode::ListMode::DirectoriesOnly) ||
     (isDirectory && mode == FSNode::ListMode::FilesOnly))
    return;

  entry._isDirectory = isDirectory;
  entry._isFile = isFile;
  entry._displayName = asciiName;
  entry._path = base;
  entry._path += asciiName;
  if(entry._isDirectory)
    entry._path += "\\";
  entry._isValid = true;
  entry._isPseudoRoot = false;

  list.emplace_back(make_shared<FSNodeWINDOWS>(entry));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
char* FSNodeWINDOWS::toAscii(TCHAR* str)
{
#ifndef UNICODE
  return str;
#else
  static char asciiString[MAX_PATH];
  WideCharToMultiByte(CP_ACP, 0, str, _tcslen(str) + 1, asciiString, sizeof(asciiString), NULL, NULL);
  return asciiString;
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const TCHAR* FSNodeWINDOWS::toUnicode(const char* str)
{
#ifndef UNICODE
  return str;
#else
  static TCHAR unicodeString[MAX_PATH];
  MultiByteToWideChar(CP_ACP, 0, str, strlen(str) + 1, unicodeString, sizeof(unicodeString) / sizeof(TCHAR));
  return unicodeString;
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FSNodeWINDOWS::FSNodeWINDOWS()
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FSNodeWINDOWS::FSNodeWINDOWS(const string& p)
  : _path{p.length() > 0 ? p : "~"}  // Default to home directory
{
  // Expand '~' to the users 'home' directory
  if(_path[0] == '~')
    _path.replace(0, 1, myHomeFinder.getHomePath());

  setFlags();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string FSNodeWINDOWS::getShortPath() const
{
  // If the path starts with the home directory, replace it with '~'
  const string& home = myHomeFinder.getHomePath();
  if(home != "" && BSPF::startsWithIgnoreCase(_path, home))
  {
    string path = "~";
    const char* offset = _path.c_str() + home.length();
    if(*offset != '\\') path += '\\';
    path += offset;
    return path;
  }
  return _path;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodeWINDOWS::
    getChildren(AbstractFSList& myList, ListMode mode) const
{
  assert(_isDirectory);

  if(_isPseudoRoot)
  {
    // Drives enumeration
    TCHAR drive_buffer[100];
    GetLogicalDriveStrings(sizeof(drive_buffer) / sizeof(TCHAR), drive_buffer);

    for(TCHAR *current_drive = drive_buffer; *current_drive;
        current_drive += _tcslen(current_drive) + 1)
    {
      FSNodeWINDOWS entry;
      char drive_name[2] = { 0, 0 };

      drive_name[0] = toAscii(current_drive)[0];
      drive_name[1] = '\0';
      entry._displayName = drive_name;
      entry._isDirectory = true;
      entry._isFile = false;
      entry._isValid = true;
      entry._isPseudoRoot = false;
      entry._path = toAscii(current_drive);
      myList.emplace_back(make_shared<FSNodeWINDOWS>(entry));
    }
  }
  else
  {
    // Files enumeration
    WIN32_FIND_DATA desc;
    HANDLE handle;

    ostringstream searchPath;
    searchPath << _path << "*";

    handle = FindFirstFile(searchPath.str().c_str(), &desc);
    if(handle == INVALID_HANDLE_VALUE)
      return false;

    addFile(myList, mode, _path.c_str(), &desc);

    while(FindNextFile(handle, &desc))
      addFile(myList, mode, _path.c_str(), &desc);

    FindClose(handle);
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
size_t FSNodeWINDOWS::getSize() const
{
  struct _stat st;
  return _stat(_path.c_str(), &st) == 0 ? st.st_size : 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodeWINDOWS::makeDir()
{
  if(!_isPseudoRoot && CreateDirectory(_path.c_str(), NULL) != 0)
  {
    setFlags();
    return true;
  }
  else
    return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodeWINDOWS::rename(const string& newfile)
{
  if(!_isPseudoRoot && MoveFile(_path.c_str(), newfile.c_str()) != 0)
  {
    setFlags();
    return true;
  }
  else
    return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
AbstractFSNodePtr FSNodeWINDOWS::getParent() const
{
  if(_isPseudoRoot)
    return nullptr;

  if(_path.size() > 3)
  {
    const char* start = _path.c_str();
    const char* end = lastPathComponent(_path);

    return make_shared<FSNodeWINDOWS>(string(start, static_cast<size_t>(end - start)));
  }
  else
    return make_shared<FSNodeWINDOWS>();
}
