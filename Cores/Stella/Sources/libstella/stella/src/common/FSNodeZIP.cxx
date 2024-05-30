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

#if defined(ZIP_SUPPORT)

#include <set>

#include "bspf.hxx"
#include "Bankswitch.hxx"
#include "FSNodeFactory.hxx"
#include "FSNodeZIP.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FSNodeZIP::FSNodeZIP(string_view p)
{
  // Extract ZIP file and virtual file (if specified)
  const size_t pos = BSPF::findIgnoreCase(p, ".zip");
  if(pos == string::npos)
    return;

  _zipFile = p.substr(0, pos+4);

  // Expand '~' to the users 'home' directory
  if(_zipFile[0] == '~')
  {
#if defined(BSPF_UNIX) || defined(BSPF_MACOS)
    const char* const home = std::getenv("HOME");  // NOLINT (not thread safe)
    if(home != nullptr)
      _zipFile.replace(0, 1, home);
#elif defined(BSPF_WINDOWS)
    _zipFile.replace(0, 1, HomeFinder::getHomePath());
#endif
  }

// cerr << " => p: " << p << '\n';

  // Open file at least once to initialize the virtual file count
  try
  {
    myZipHandler->open(_zipFile);
  }
  catch(const runtime_error&)
  {
    // TODO: Actually present the error passed in back to the user
    //       For now, we just indicate that no ROMs were found
    _error = zip_error::NO_ROMS;
  }
  _numFiles = myZipHandler->romFiles();
  if(_numFiles == 0)
  {
    _error = zip_error::NO_ROMS;
  }

  // We always need a virtual file/path
  // Either one is given, or we use the first one
  if(pos+5 < p.length())  // if something comes after '.zip'
  {
    _virtualPath = p.substr(pos+5);
    _isFile = Bankswitch::isValidRomName(_virtualPath);
    _isDirectory = !_isFile;
  }
  else if(_numFiles == 1)
  {
    bool found = false;
    while(myZipHandler->hasNext() && !found)
    {
      const auto& [name, size] = myZipHandler->next();
      if(Bankswitch::isValidRomName(name))
      {
        _virtualPath = name;
        _size = size;
        _isFile = true;

        found = true;
      }
    }
    if(!found)
      return;
  }
  else if(_numFiles > 1)
    _isDirectory = true;

  // Create a concrete FSNode to use
  // This *must not* be a ZIP file; it must be a real FSNode object that
  // has direct access to the actual filesystem (aka, a 'System' node)
  // Behind the scenes, this node is actually a platform-specific object
  // for whatever system we are running on
  _realNode = FSNodeFactory::create(_zipFile,
      FSNodeFactory::Type::SYSTEM);

  setFlags(_zipFile, _virtualPath, _realNode);
// cerr << "==============================================================\n";
// cerr << _name << ", file: " << _isFile << ", dir: " << _isDirectory << "\n\n";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FSNodeZIP::FSNodeZIP(const string& zipfile, const string& virtualpath,
                     const AbstractFSNodePtr& realnode, size_t size, bool isdir)
  : _size{size},
    _isDirectory{isdir},
    _isFile{!isdir}
{
// cerr << "=> c'tor 2: " << zipfile << ", " << virtualpath << ", " << isdir << '\n';
  setFlags(zipfile, virtualpath, realnode);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FSNodeZIP::setFlags(const string& zipfile, const string& virtualpath,
                         const AbstractFSNodePtr& realnode)
{
  _zipFile = zipfile;
  _virtualPath = virtualpath;
  _realNode = realnode;

  _path = _realNode->getPath();
  _shortPath = _realNode->getShortPath();

  // Is a file component present?
  if(!_virtualPath.empty())
  {
    _path += ("/" + _virtualPath);
    _shortPath += ("/" + _virtualPath);
  }
  _name = lastPathComponent(_path);

  if(!_realNode->isFile())
    _error = zip_error::NOT_A_FILE;
  if(!_realNode->isReadable())
    _error = zip_error::NOT_READABLE;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodeZIP::exists() const
{
  if(_realNode && _realNode->exists())
  {
    // We need to inspect the actual path, not just the ZIP file itself
    try
    {
      myZipHandler->open(_zipFile);
      while(myZipHandler->hasNext())
      {
        const auto& [name, size] = myZipHandler->next();
        if(BSPF::startsWithIgnoreCase(name, _virtualPath))
          return true;
      }
    }
    catch(const runtime_error&)
    {
      // TODO: Actually present the error passed in back to the user
      cerr << "ERROR: FSNodeZIP::exists()\n";
    }
  }

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodeZIP::getChildren(AbstractFSList& myList, ListMode mode) const
{
  // Files within ZIP archives don't contain children
  if(!isDirectory() || _error != zip_error::NONE)
    return false;

  std::set<string> dirs;
  myZipHandler->open(_zipFile);
  while(myZipHandler->hasNext())
  {
    // Only consider entries that start with '_virtualPath'
    // Ignore empty filenames and '__MACOSX' virtual directories
    const auto& [name, size] = myZipHandler->next();
    if(BSPF::startsWithIgnoreCase(name, "__MACOSX") || name == EmptyString)
      continue;
    if(BSPF::startsWithIgnoreCase(name, _virtualPath))
    {
      // First strip off the leading directory
      const string& curr = name.substr(
          _virtualPath.empty() ? 0 : _virtualPath.size()+1);

      // Only add sub-directory entries once
      const auto pos = curr.find_first_of("/\\");
      if(pos != string::npos)
        dirs.emplace(curr.substr(0, pos));
      else
        myList.emplace_back(new FSNodeZIP(_zipFile, name, _realNode, size, false));
    }
  }
  for(const auto& dir: dirs)
  {
    // Prepend previous path
    const string& vpath = !_virtualPath.empty() ? _virtualPath + "/" + dir : dir;
    myList.emplace_back(new FSNodeZIP(_zipFile, vpath, _realNode, 0, true));
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
size_t FSNodeZIP::read(ByteBuffer& buffer, size_t) const
{
  switch(_error)
  {
    case zip_error::NONE:         break;
    case zip_error::NOT_A_FILE:   throw runtime_error("ZIP file contains errors/not found");
    case zip_error::NOT_READABLE: throw runtime_error("ZIP file not readable");
    case zip_error::NO_ROMS:      throw runtime_error("ZIP file doesn't contain any ROMs");
  }

  myZipHandler->open(_zipFile);

  bool found = false;
  while(myZipHandler->hasNext() && !found)
  {
    const auto& [name, size] = myZipHandler->next();
    found = name == _virtualPath;
  }

  return found ? myZipHandler->decompress(buffer) : 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
size_t FSNodeZIP::read(stringstream& buffer) const
{
  // For now, we just read into a buffer and store in the stream
  // TODO: maybe there's a more efficient way to do this?
  ByteBuffer read_buf;
  const size_t size = read(read_buf, 0);
  if(size > 0)
    buffer.write(reinterpret_cast<char*>(read_buf.get()), size);

  return size;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
size_t FSNodeZIP::write(const ByteBuffer& buffer, size_t) const
{
  // TODO: Not yet implemented
  throw runtime_error("ZIP file not writable");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
size_t FSNodeZIP::write(const stringstream& buffer) const
{
  // TODO: Not yet implemented
  throw runtime_error("ZIP file not writable");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
AbstractFSNodePtr FSNodeZIP::getParent() const
{
  if(_virtualPath.empty())
    return _realNode ? _realNode->getParent() : nullptr;

  // TODO: For some reason, getting the stem for normal paths and zip paths
  //       behaves differently.  For now, we'll use the old method here.
  auto STEM_FOR_ZIP = [](string_view s) {
    const char* const start = s.data();
    const char* cur = start + s.size() - 2;

    while (cur >= start && !(*cur == '/' || *cur == '\\'))
      --cur;

    return s.substr(0, (cur + 1) - start - 1);
  };

  return make_unique<FSNodeZIP>(STEM_FOR_ZIP(_path));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
unique_ptr<ZipHandler> FSNodeZIP::myZipHandler = make_unique<ZipHandler>();

#endif  // ZIP_SUPPORT
