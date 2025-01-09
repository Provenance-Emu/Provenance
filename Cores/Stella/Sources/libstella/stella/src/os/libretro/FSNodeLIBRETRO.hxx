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

#ifndef FS_NODE_LIBRETRO_HXX
#define FS_NODE_LIBRETRO_HXX

#include "FSNode.hxx"

/*
 * Implementation of the Stella file system API based on LIBRETRO API.
 *
 * Parts of this class are documented in the base interface class,
 * AbstractFSNode.
 */
class FSNodeLIBRETRO : public AbstractFSNode
{
  public:
    FSNodeLIBRETRO();

    explicit FSNodeLIBRETRO(string_view path);

    bool exists() const override;
    const string& getName() const override  { return _name; }
    void setName(string_view name) override { _name = name; }
    const string& getPath() const override { return _path; }
    string getShortPath() const override;
    bool hasParent() const override { return false; }
    bool isDirectory() const override { return _isDirectory; }
    bool isFile() const override      { return _isFile;      }
    bool isReadable() const override;
    bool isWritable() const override;
    bool makeDir() override;
    bool rename(string_view newfile) override;

    bool getChildren(AbstractFSList& list, ListMode mode) const override;
    AbstractFSNodePtr getParent() const override;

    size_t read(ByteBuffer& image, size_t) const override;

  protected:
    string _name;
    string _path;
    bool _isDirectory{false};
    bool _isFile{true};
    bool _isValid{true};
};

#endif
