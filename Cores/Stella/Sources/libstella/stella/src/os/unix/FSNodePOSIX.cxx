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
FSNodePOSIX::FSNodePOSIX(string_view path, bool verify)
  : _path{!path.empty() ? path : "~"}  // Default to home directory
{
  // Expand '~' to the HOME environment variable
  if (_path[0] == '~')
  {
    if (ourHomeDir != nullptr)
      _path.replace(0, 1, ourHomeDir);
  }
  // Get absolute path (only used for relative directories)
  else if (_path[0] == '.')
  {
    if(realpath(_path.c_str(), ourBuf.data()))
      _path = ourBuf.data();
  }

  _displayName = lastPathComponent(_path);

  if (verify)
    setFlags();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodePOSIX::setFlags()
{
  struct stat st;
  if (stat(_path.c_str(), &st) == 0)
  {
    _isDirectory = S_ISDIR(st.st_mode);
    _isFile = S_ISREG(st.st_mode);
    _size = st.st_size;

    // Add a trailing slash, if necessary
    if (_isDirectory && !_path.empty() &&
        _path.back() != FSNode::PATH_SEPARATOR)
      _path += FSNode::PATH_SEPARATOR;

    return true;
  }
  else
  {
    _isDirectory = _isFile = false;
    _size = 0;

    return false;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string FSNodePOSIX::getShortPath() const
{
  // If the path starts with the home directory, replace it with '~'
  const string& home = ourHomeDir != nullptr ? ourHomeDir : EmptyString;

  if (home != EmptyString && BSPF::startsWithIgnoreCase(_path, home))
  {
    string path = "~";
    const char* const offset = _path.c_str() + home.size();
    if (*offset != FSNode::PATH_SEPARATOR)
      path += FSNode::PATH_SEPARATOR;
    path += offset;
    return path;
  }
  return _path;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
size_t FSNodePOSIX::getSize() const
{
  if (_size == 0 && _isFile)
  {
    struct stat st;
    _size = (stat(_path.c_str(), &st) == 0) ? st.st_size : 0;
  }
  return _size;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodePOSIX::hasParent() const
{
  return !_path.empty() && _path != ROOT_DIR;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
AbstractFSNodePtr FSNodePOSIX::getParent() const
{
  if (_path == ROOT_DIR)
    return nullptr;

  return make_unique<FSNodePOSIX>(stemPathComponent(_path));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodePOSIX::getChildren(AbstractFSList& myList, ListMode mode) const
{
  if (!_isDirectory)
    return false;

  DIR* dirp = opendir(_path.c_str());
  if (dirp == nullptr)
    return false;

  // Loop over dir entries using readdir
  struct dirent* dp = nullptr;
  while ((dp = readdir(dirp)) != nullptr)  // NOLINT (not thread safe)
  {
    // Ignore all hidden files
    if (dp->d_name[0] == '.')
      continue;

    string newPath(_path);
    if (!newPath.empty() && newPath.back() != FSNode::PATH_SEPARATOR)
      newPath += FSNode::PATH_SEPARATOR;
    newPath += dp->d_name;

    FSNodePOSIX entry(newPath, false);
    bool valid = true;

    if (dp->d_type == DT_UNKNOWN || dp->d_type == DT_LNK)
    {
      // Fall back to stat()
      valid = entry.setFlags();
    }
    else
    {
      entry._isDirectory = (dp->d_type == DT_DIR);
      entry._isFile = (dp->d_type == DT_REG);
      // entry._size will be calculated first time ::getSize() is called

      if (entry._isDirectory)
        entry._path += FSNode::PATH_SEPARATOR;
    }

    // Skip files that are invalid for some reason (e.g. because we couldn't
    // properly stat them).
    if (!valid)
      continue;

    // Honor the chosen mode
    if ((mode == FSNode::ListMode::FilesOnly && !entry._isFile) ||
        (mode == FSNode::ListMode::DirectoriesOnly && !entry._isDirectory))
      continue;

    myList.emplace_back(make_unique<FSNodePOSIX>(entry));
  }
  closedir(dirp);

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodePOSIX::makeDir()
{
  if (mkdir(_path.c_str(), 0777) == 0)
  {
    // Get absolute path
    if (realpath(_path.c_str(), ourBuf.data()))
      _path = ourBuf.data();

    _displayName = lastPathComponent(_path);
    return setFlags();
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodePOSIX::rename(string_view newfile)
{
  if (std::rename(_path.c_str(), string{newfile}.c_str()) == 0)
  {
    _path = newfile;

    // Get absolute path
    if (realpath(_path.c_str(), ourBuf.data()))
      _path = ourBuf.data();

    _displayName = lastPathComponent(_path);
    return setFlags();
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const char* const FSNodePOSIX::ourHomeDir = std::getenv("HOME"); // NOLINT (not thread safe)
std::array<char, MAXPATHLEN> FSNodePOSIX::ourBuf = { 0 };
