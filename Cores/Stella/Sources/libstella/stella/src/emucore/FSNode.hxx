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

#ifndef FS_NODE_HXX
#define FS_NODE_HXX

#include <functional>

#include "bspf.hxx"

/*
 * The API described in this header is meant to allow for file system browsing in a
 * portable fashion. To this end, multiple or single roots have to be supported
 * (compare Unix with a single root, Windows with multiple roots C:, D:, ...).
 *
 * To this end, we abstract away from paths; implementations can be based on
 * paths (and it's left to them whether / or \ or : is the path separator :-).
 */

class FSNode;
class AbstractFSNode;
using AbstractFSNodePtr = shared_ptr<AbstractFSNode>;

/**
 * List of multiple file system nodes. E.g. the contents of a given directory.
 * This is subclass instead of just a typedef so that we can use forward
 * declarations of it in other places.
 */
class FSList : public vector<FSNode> { };

/**
 * This class acts as a wrapper around the AbstractFSNode class defined
 * in backends/fs.
 */
class FSNode
{
  public:
  #ifdef BSPF_WINDOWS
    static constexpr char PATH_SEPARATOR = '\\';
  #else
    static constexpr char PATH_SEPARATOR = '/';
  #endif

  public:
    /**
     * Flag to tell listDir() which kind of files to list.
     */
    enum class ListMode { FilesOnly, DirectoriesOnly, All };

    /** Function used to filter the file listing.  Returns true if the filename
        should be included, else false.*/
    using NameFilter = std::function<bool(const FSNode& node)>;
    using CancelCheck = std::function<bool()> const;

    /**
     * Create a new pathless FSNode. Since there's no path associated
     * with this node, path-related operations (i.e. exists(), isDirectory(),
     * getPath()) will always return false or raise an assertion.
     */
    FSNode() = default;
    ~FSNode() = default;

    /**
     * Create a new FSNode referring to the specified path. This is
     * the counterpart to the path() method.
     *
     * If path is empty or equals '~', then a node representing the
     * "home directory" will be created. If that is not possible (since e.g. the
     * operating system doesn't support the concept), some other directory is
     * used (usually the root directory).
     */
    explicit FSNode(string_view path);

    /**
     * Assignment operators.
     */
    FSNode(const FSNode&) = default;
    FSNode& operator=(const FSNode&) = default;
    FSNode& operator=(FSNode&&) = default;
    FSNode(FSNode&&) = default;

    /**
     * Compare the name of this node to the name of another, testing for
     * equality.
     */
    inline bool operator==(const FSNode& node) const
    {
      return BSPF::compareIgnoreCase(getName(), node.getName()) == 0;
    }

    /**
     * Append the given path to the node, adding a directory separator
     * when necessary.  Modelled on the C++17 fs::path API.
     */
    FSNode& operator/=(string_view path);

    /**
     * By default, the output operator simply outputs the fully-qualified
     * pathname of the node.
     */
    friend ostream& operator<<(ostream& os, const FSNode& node)
    {
      return os << node.getPath();
    }

    /**
     * Indicates whether the object referred by this path exists in the
     * filesystem or not.
     *
     * @return bool true if the path exists, false otherwise.
     */
    bool exists() const;

    /**
     * Return a list of child nodes of this and all sub-directories. If called on a node
     * that does not represent a directory, false is returned.
     *
     * @return true if successful, false otherwise (e.g. when the directory
     *         does not exist).
     */
    bool getAllChildren(FSList& fslist, ListMode mode = ListMode::DirectoriesOnly,
                        const NameFilter& filter = [](const FSNode&) { return true; },
                        bool includeParentDirectory = true,
                        const CancelCheck& isCancelled = []() { return false; }) const;

    /**
     * Return a list of child nodes of this directory node. If called on a node
     * that does not represent a directory, false is returned.
     *
     * @return true if successful, false otherwise (e.g. when the directory
     *         does not exist).
     */
    bool getChildren(FSList& fslist, ListMode mode = ListMode::DirectoriesOnly,
                     const NameFilter& filter = [](const FSNode&){ return true; },
                     bool includeChildDirectories = false,
                     bool includeParentDirectory = true,
                     const CancelCheck& isCancelled = []() { return false; }) const;

    /**
     * Set/get a string representation of the name of the file. This is can be
     * used e.g. by detection code that relies on matching the name of a given
     * file. But it is *not* suitable for use with fopen / File::open, nor
     * should it be archived.
     *
     * @return the file name
     */
    const string& getName() const;
    void setName(string_view name);

    /**
     * Return a string representation of the file which can be passed to fopen().
     * This will usually be a 'path' (hence the name of the method), but can
     * be anything that fulfills the above criterions.
     *
     * @return the 'path' represented by this filesystem node
     */
    const string& getPath() const;

    /**
     * Return a string representation of the file which contains the '~'
     * symbol (if applicable), and is suitable for archiving (i.e. writing
     * to the config file).
     *
     * @return the 'path' represented by this filesystem node
     */
    string getShortPath() const;

    /**
     * Determine whether this node has a parent.
     */
    bool hasParent() const;

    /**
     * Get the parent node of this node. If this node has no parent node,
     * then it returns a duplicate of this node.
     */
    FSNode getParent() const;

    /**
     * Indicates whether the path refers to a directory or not.
     */
    bool isDirectory() const;

    /**
     * Indicates whether the path refers to a real file or not.
     *
     * Currently, a symlink or pipe is not considered a file.
     */
    bool isFile() const;

    /**
     * Indicates whether the object referred by this path can be read from or not.
     *
     * If the path refers to a directory, readability implies being able to read
     * and list the directory entries.
     *
     * If the path refers to a file, readability implies being able to read the
     * contents of the file.
     *
     * @return bool true if the object can be read, false otherwise.
     */
    bool isReadable() const;

    /**
     * Indicates whether the object referred by this path can be written to or not.
     *
     * If the path refers to a directory, writability implies being able to modify
     * the directory entry (i.e. rename the directory, remove it or write files
     * inside of it).
     *
     * If the path refers to a file, writability implies being able to write data
     * to the file.
     *
     * @return bool true if the object can be written to, false otherwise.
     */
    bool isWritable() const;

    /**
     * Create a directory from the current node path.
     *
     * @return bool true if the directory was created, false otherwise.
     */
    bool makeDir();

    /**
     * Rename the current node path with the new given name.
     *
     * @return bool true if the node was renamed, false otherwise.
     */
    bool rename(string_view newfile);

    /**
     * Get the size of the current node path.
     *
     * @return  Size (in bytes) of the current node path.
     */
    size_t getSize() const;

    /**
     * Read data (binary format) into the given buffer.
     *
     * @param buffer  The buffer to contain the data (allocated in this method).
     * @param size    The amount of data to read (0 means read all data).
     *
     * @return  The number of bytes read (0 in the case of failure)
     *          This method can throw exceptions, and should be used inside
     *          a try-catch block.
     */
    size_t read(ByteBuffer& buffer, size_t size = 0) const;

    /**
     * Read data (text format) into the given stream.
     *
     * @param buffer  The buffer stream to contain the data.
     *
     * @return  The number of bytes read (0 in the case of failure)
     *          This method can throw exceptions, and should be used inside
     *          a try-catch block.
     */
    size_t read(stringstream& buffer) const;

    /**
     * Write data (binary format) from the given buffer.
     *
     * @param buffer  The buffer that contains the data.
     * @param size    The size of the buffer.
     *
     * @return  The number of bytes written (0 in the case of failure)
     *          This method can throw exceptions, and should be used inside
     *          a try-catch block.
     */
    size_t write(const ByteBuffer& buffer, size_t size) const;

    /**
     * Write data (text format) from the given stream.
     *
     * @param buffer  The buffer stream that contains the data.
     *
     * @return  The number of bytes written (0 in the case of failure)
     *          This method can throw exceptions, and should be used inside
     *          a try-catch block.
     */
    size_t write(const stringstream& buffer) const;

    /**
     * The following methods are almost exactly the same as the various
     * getXXXX() methods above.  Internally, they call the respective methods
     * and replace the extension (if present) with the given one.  If no
     * extension is present, the given one is appended instead.
     */
    string getNameWithExt(string_view ext = "") const;
    string getPathWithExt(string_view ext = "") const;

  private:
    explicit FSNode(const AbstractFSNodePtr& realNode);
    AbstractFSNodePtr _realNode;
    void setPath(string_view path);
};


/**
 * Abstract file system node.  Private subclasses implement the actual
 * functionality.
 *
 * Most of the methods correspond directly to methods in class FSNode,
 * so if they are not documented here, look there for more information about
 * the semantics.
 */

using AbstractFSList = vector<AbstractFSNodePtr>;

class AbstractFSNode
{
  protected:
    friend class FSNode;
    using ListMode = FSNode::ListMode;
    using NameFilter = FSNode::NameFilter;

  public:
    /**
     * Assignment operators.
     */
    AbstractFSNode() = default;
    AbstractFSNode(const AbstractFSNode&) = default;
    AbstractFSNode(AbstractFSNode&&) = delete;
    AbstractFSNode& operator=(const AbstractFSNode&) = default;
    AbstractFSNode& operator=(AbstractFSNode&&) = delete;
    virtual ~AbstractFSNode() = default;

    /*
     * Indicates whether the object referred by this path exists in the
     * filesystem or not.
     */
    virtual bool exists() const = 0;

    /**
     * Return a list of child nodes of this directory node. If called on a node
     * that does not represent a directory, false is returned.
     *
     * @param list List to put the contents of the directory in.
     * @param mode Mode to use while listing the directory.
     *
     * @return true if successful, false otherwise (e.g. when the directory
     *         does not exist).
     */
    virtual bool getChildren(AbstractFSList& list, ListMode mode) const = 0;

    /**
     * Returns the last component of the path pointed by this FSNode.
     *
     * Examples (POSIX):
     *			/foo/bar.txt would return /bar.txt
     *			/foo/bar/    would return /bar/
     *
     * @note This method is very architecture dependent, please check the concrete
     *       implementation for more information.
     */
    virtual const string& getName() const = 0;
    virtual void setName(string_view name) = 0;

    /**
     * Returns the 'path' of the current node, usable in fopen().
     */
    virtual const string& getPath() const = 0;

    /**
     * Returns the 'path' of the current node, containing '~' and for archiving.
     */

    virtual string getShortPath() const = 0;

    /**
     * Determine whether this node has a parent.
     */
    virtual bool hasParent() const = 0;

    /**
     * The parent node of this directory.
     * The parent of the root is 'nullptr'.
     */
    virtual AbstractFSNodePtr getParent() const = 0;

    /**
     * Indicates whether this path refers to a directory or not.
     */
    virtual bool isDirectory() const = 0;

    /**
     * Indicates whether this path refers to a real file or not.
     */
    virtual bool isFile() const = 0;

    /**
     * Indicates whether the object referred by this path can be read from or not.
     *
     * If the path refers to a directory, readability implies being able to read
     * and list the directory entries.
     *
     * If the path refers to a file, readability implies being able to read the
     * contents of the file.
     *
     * @return bool true if the object can be read, false otherwise.
     */
    virtual bool isReadable() const = 0;

    /**
     * Indicates whether the object referred by this path can be written to or not.
     *
     * If the path refers to a directory, writability implies being able to modify
     * the directory entry (i.e. rename the directory, remove it or write files
     * inside of it).
     *
     * If the path refers to a file, writability implies being able to write data
     * to the file.
     *
     * @return bool true if the object can be written to, false otherwise.
     */
    virtual bool isWritable() const = 0;

    /**
     * Create a directory from the current node path.
     *
     * @return bool true if the directory was created, false otherwise.
     */
    virtual bool makeDir() = 0;

    /**
     * Rename the current node path with the new given name.
     *
     * @return bool true if the node was renamed, false otherwise.
     */
    virtual bool rename(string_view newfile) = 0;

    /**
     * Get the size of the current node path.
     *
     * @return  Size (in bytes) of the current node path.
     */
    virtual size_t getSize() const { return 0; }

    /**
     * Read data (binary format) into the given buffer.
     *
     * @param buffer  The buffer to contain the data (allocated in this method).
     * @param size    The amount of data to read (0 means read all data).
     *
     * @return  The number of bytes read (0 in the case of failure)
     *          This method can throw exceptions, and should be used inside
     *          a try-catch block.
     */
    virtual size_t read(ByteBuffer& buffer, size_t size) const { return 0; }

    /**
     * Read data (text format) into the given stream.
     *
     * @param buffer  The buffer stream to contain the data.
     *
     * @return  The number of bytes read (0 in the case of failure)
     *          This method can throw exceptions, and should be used inside
     *          a try-catch block.
     */
    virtual size_t read(stringstream& buffer) const { return 0; }

    /**
     * Write data (binary format) from the given buffer.
     *
     * @param buffer  The buffer that contains the data.
     * @param size    The size of the buffer.
     *
     * @return  The number of bytes written (0 in the case of failure)
     *          This method can throw exceptions, and should be used inside
     *          a try-catch block.
     */
    virtual size_t write(const ByteBuffer& buffer, size_t size) const { return 0; }

    /**
     * Write data (text format) from the given stream.
     *
     * @param buffer  The buffer stream that contains the data.
     *
     * @return  The number of bytes written (0 in the case of failure)
     *          This method can throw exceptions, and should be used inside
     *          a try-catch block.
     */
    virtual size_t write(const stringstream& buffer) const { return 0; }

  protected:
    /**
     * Returns the last component of a given path.
     *
     * @param s  String containing the path.
     * @return   View of the last component inside s.
     */
    static constexpr string_view lastPathComponent(string_view s)
    {
      if(s.empty())  return EmptyString;
      const auto pos = s.find_last_of("/\\", s.size() - 2);
      return s.substr(pos + 1);
    }

    /**
     * Returns the part *before* the last component of a given path.
     *
     * @param s  String containing the path.
     * @return   View of the preceding (before the last) component inside s.
     */
    static constexpr string_view stemPathComponent(string_view s)
    {
      if(s.empty())  return EmptyString;
      const auto pos = s.find_last_of("/\\", s.size() - 2);
      return s.substr(0, pos + 1);
    }
};

#endif
