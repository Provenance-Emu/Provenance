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

#include "bspf.hxx"
#include "Cart.hxx"
#include "FSNodeLIBRETRO.hxx"

#ifdef _WIN32
  const string SLASH = "\\";
#else
  const string SLASH = "/";
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FSNodeLIBRETRO::FSNodeLIBRETRO()
  : _name{"rom"},
    _path{"." + SLASH}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FSNodeLIBRETRO::FSNodeLIBRETRO(string_view p)
  : _name{p},
    _path{p}
{
  // TODO: use retro_vfs_mkdir_t (file) or RETRO_MEMORY_SAVE_RAM (stream) or libretro save path
  if(p == "." + SLASH + "nvram")
    _path = "." + SLASH;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodeLIBRETRO::exists() const
{
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodeLIBRETRO::isReadable() const
{
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodeLIBRETRO::isWritable() const
{
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string FSNodeLIBRETRO::getShortPath() const
{
  return ".";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodeLIBRETRO::
    getChildren(AbstractFSList& myList, ListMode mode) const
{
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodeLIBRETRO::makeDir()
{
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FSNodeLIBRETRO::rename(string_view newfile)
{
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
AbstractFSNodePtr FSNodeLIBRETRO::getParent() const
{
  return nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
size_t FSNodeLIBRETRO::read(ByteBuffer& image, size_t) const
{
  image = make_unique<uInt8[]>(Cartridge::maxSize());

  extern uInt32 libretro_read_rom(void* data);
  return libretro_read_rom(image.get());
}
