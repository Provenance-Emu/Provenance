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

#ifndef FS_NODE_WINDOWS_HXX
#define FS_NODE_WINDOWS_HXX

#include "FSNode.hxx"
#include "HomeFinder.hxx"

// TODO - fix isFile() functionality so that it actually determines if something
//        is a file; for now, it assumes a file if it isn't a directory

/*
 * Implementation of the Stella file system API based on Windows API.
 *
 * Parts of this class are documented in the base interface class,
 * AbstractFSNode.
 */
class FSNodeWINDOWS : public AbstractFSNode
{
  public:
    /**
     * Creates a FSNodeWINDOWS with the root node as path.
     *
     * In regular windows systems, a virtual root path is used "".
     */
    FSNodeWINDOWS() : _isPseudoRoot{true}, _isDirectory{true} { }

    /**
     * Creates a FSNodeWINDOWS for a given path.
     *
     * Examples:
     *   path=c:\foo\bar.txt, currentDir=false -> c:\foo\bar.txt
     *   path=c:\foo\bar.txt, currentDir=true -> current directory
     *   path=NULL, currentDir=true -> current directory
     *
     * @param path String with the path the new node should point to.
     */
    explicit FSNodeWINDOWS(string_view path);

    bool exists() const override;
    const string& getName() const override  { return _displayName; }
    void setName(string_view name) override { _displayName = name; }
    const string& getPath() const override { return _path; }
    string getShortPath() const override;
    bool isDirectory() const override { return _isDirectory; }
    bool isFile() const override      { return _isFile;      }
    bool isReadable() const override;
    bool isWritable() const override;
    bool makeDir() override;
    bool rename(string_view newfile) override;

    size_t getSize() const override;
    bool hasParent() const override { return !_isPseudoRoot; }
    AbstractFSNodePtr getParent() const override;
    bool getChildren(AbstractFSList& list, ListMode mode) const override;

  private:
    /**
     * Set the _isDirectory/_isFile/_size flags using GetFileAttributes().
     *
     * @return  Success/failure of GetFileAttributes() function
     */
    bool setFlags();

  private:
    string _displayName, _path;
    bool _isPseudoRoot{false}, _isDirectory{false}, _isFile{false};
    mutable size_t _size{0};
};

#endif
