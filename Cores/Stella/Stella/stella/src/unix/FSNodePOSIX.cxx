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

#if defined(RETRON77)
  #define ROOT_DIR "/mnt/games/"
#else
  #define ROOT_DIR "/"
#endif

#include "FSNodePOSIX.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FSNodePOSIX::FSNodePOSIX()
  : _path{ROOT_DIR},
    _displayName{_path}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FSNodePOSIX::FSNodePOSIX(const string& path, bool verify)
  : _path{path.length() > 0 ? path : "~"}  // Default to home directory
{
  // Expand '~' to the HOME environment variable
  if(_path[0] == '~')
  {
    const char* home = std::getenv("HOME");
    if (home != nullptr)
      _path.replace(0, 1, home);
  }
  // Get absolute path (only used for relative directories)
  else if(_path[0] == '.')
  {
    std::array<char, MAXPATHLEN> buf;
    if(realpath(_path.c_str(), buf.data()))
      _path = buf.data();
  }

  _displayName = lastPathComponent(_path);

  if(verify)
    setFlags();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FSNodePOSIX::setFlags()
{
  struct stat st;

  _isValid = (0 == stat(_path.c_str(), &st));
  if(_isValid)
  {
    _isDirectory = S_ISDIR(st.st_mode);
    _isFile = S_ISREG(st.st_mode);

    // Add a trailing slash, if necessary
    if (_isDirectory && _path.length() > 0 && _path[_path.length()-1] != '/')
      _path += '/';
  }
  else
    _isDirectory = _isFile = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string FSNodePOSIX::getShortPath() const
{
  // If the path starts with the home directory, replace it with '~'
  const char* env_home = std::getenv("HOME");
  const string& home = env_home != nullptr ? env_home : EmptyString;

  if(home != EmptyString && BSPF::startsWithIgnoreCase(_path, home))
  {
    string path = "~";
    const char* offset = _path.c_str() + home.size();
    if(*offset != '/') path += "/";
    path += offset;
    return path;
  }
  return _path;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodePOSIX::hasParent() const
{
  return _path != "" && _path != ROOT_DIR;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodePOSIX::getChildren(AbstractFSList& myList, ListMode mode) const
{
  assert(_isDirectory);

  DIR* dirp = opendir(_path.c_str());
  if (dirp == nullptr)
    return false;

  // Loop over dir entries using readdir
  struct dirent* dp = nullptr;
  while ((dp = readdir(dirp)) != nullptr)
  {
    // Ignore all hidden files
    if (dp->d_name[0] == '.')
      continue;

    string newPath(_path);
    if (newPath.length() > 0 && newPath[newPath.length()-1] != '/')
      newPath += '/';
    newPath += dp->d_name;

    FSNodePOSIX entry(newPath, false);

#if defined(SYSTEM_NOT_SUPPORTING_D_TYPE)
    /* TODO: d_type is not part of POSIX, so it might not be supported
     * on some of our targets. For those systems where it isn't supported,
     * add this #elif case, which tries to use stat() instead.
     *
     * The d_type method is used to avoid costly recurrent stat() calls in big
     * directories.
     */
    entry.setFlags();
#else
    if (dp->d_type == DT_UNKNOWN)
    {
      // Fall back to stat()
      entry.setFlags();
    }
    else
    {
      if (dp->d_type == DT_LNK)
      {
        struct stat st;
        if (stat(entry._path.c_str(), &st) == 0)
        {
          entry._isDirectory = S_ISDIR(st.st_mode);
          entry._isFile = S_ISREG(st.st_mode);
        }
        else
          entry._isDirectory = entry._isFile = false;
      }
      else
      {
        entry._isDirectory = (dp->d_type == DT_DIR);
        entry._isFile = (dp->d_type == DT_REG);
      }

      if (entry._isDirectory)
        entry._path += "/";

      entry._isValid = true;
    }
#endif

    // Skip files that are invalid for some reason (e.g. because we couldn't
    // properly stat them).
    if (!entry._isValid)
      continue;

    // Honor the chosen mode
    if ((mode == FSNode::ListMode::FilesOnly && !entry._isFile) ||
        (mode == FSNode::ListMode::DirectoriesOnly && !entry._isDirectory))
      continue;

    myList.emplace_back(make_shared<FSNodePOSIX>(entry));
  }
  closedir(dirp);

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
size_t FSNodePOSIX::getSize() const
{
  struct stat st;
  return (stat(_path.c_str(), &st) == 0) ? st.st_size : 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodePOSIX::makeDir()
{
  if(mkdir(_path.c_str(), 0777) == 0)
  {
    // Get absolute path
    std::array<char, MAXPATHLEN> buf;
    if(realpath(_path.c_str(), buf.data()))
      _path = buf.data();

    _displayName = lastPathComponent(_path);
    setFlags();

    // Add a trailing slash, if necessary
    if (_path.length() > 0 && _path[_path.length()-1] != '/')
      _path += '/';

    return true;
  }
  else
    return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodePOSIX::rename(const string& newfile)
{
  if(std::rename(_path.c_str(), newfile.c_str()) == 0)
  {
    _path = newfile;

    // Get absolute path
    std::array<char, MAXPATHLEN> buf;
    if(realpath(_path.c_str(), buf.data()))
      _path = buf.data();

    _displayName = lastPathComponent(_path);
    setFlags();

    // Add a trailing slash, if necessary
    if (_isDirectory && _path.length() > 0 && _path[_path.length()-1] != '/')
      _path += '/';

    return true;
  }
  else
    return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
AbstractFSNodePtr FSNodePOSIX::getParent() const
{
  if (_path == ROOT_DIR)
    return nullptr;

  const char* start = _path.c_str();
  const char* end = lastPathComponent(_path);

  return make_unique<FSNodePOSIX>(string(start, size_t(end - start)));
}
