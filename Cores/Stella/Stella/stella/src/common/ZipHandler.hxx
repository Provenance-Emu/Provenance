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

#if defined(ZIP_SUPPORT)

#ifndef ZIP_HANDLER_HXX
#define ZIP_HANDLER_HXX

#include <tuple>

#include "bspf.hxx"

/**
  This class implements a thin wrapper around the zip file management code
  from the MAME project.

  @author  Original code by Aaron Giles, ZipHandler wrapper class and heavy
           modifications/refactoring by Stephen Anthony.
*/
class ZipHandler
{
  public:
    ZipHandler() = default;

    // Open ZIP file for processing
    // An exception will be thrown on any errors
    void open(const string& filename);

    // The following form an iterator for processing the filenames in the ZIP file
    void reset();          // Reset iterator to first file
    bool hasNext() const;  // Answer whether there are more files present
    std::tuple<string, size_t> next();  // Get information on next file

    // Decompress the currently selected file and return its length
    // An exception will be thrown on any errors
    uInt64 decompress(ByteBuffer& image);

    // Answer the number of ROM files (with a valid extension) found
    uInt16 romFiles() const { return myZip ? myZip->myRomfiles : 0; }

  private:
    // Error types
    enum class ZipError
    {
      NONE = 0,
      OUT_OF_MEMORY,
      FILE_ERROR,
      BAD_SIGNATURE,
      DECOMPRESS_ERROR,
      FILE_TRUNCATED,
      FILE_CORRUPT,
      UNSUPPORTED,
      LZMA_UNSUPPORTED,
      BUFFER_TOO_SMALL
    };

    // Contains extracted file header information
    struct ZipHeader
    {
      uInt16 versionCreated{0};      // version made by
      uInt16 versionNeeded{0};       // version needed to extract
      uInt16 bitFlag{0};             // general purpose bit flag
      uInt16 compression{0};         // compression method
      uInt16 fileTime{0};            // last mod file time
      uInt16 fileDate{0};            // last mod file date
      uInt32 crc{0};                 // crc-32
      uInt64 compressedLength{0};    // compressed size
      uInt64 uncompressedLength{0};  // uncompressed size
      uInt32 startDiskNumber{0};     // disk number start
      uInt64 localHeaderOffset{0};   // relative offset of local header
      string filename;               // filename
    };

    // Contains extracted end of central directory information
    struct ZipEcd
    {
      uInt32 diskNumber{0};        // number of this disk
      uInt32 cdStartDiskNumber{0}; // number of the disk with the start of the central directory
      uInt64 cdDiskEntries{0};     // total number of entries in the central directory on this disk
      uInt64 cdTotalEntries{0};    // total number of entries in the central directory
      uInt64 cdSize{0};            // size of the central directory
      uInt64 cdStartDiskOffset{0}; // offset of start of central directory with respect to the starting disk number
    };

    // Describes an open ZIP file
    struct ZipFile
    {
      string  myFilename;     // copy of ZIP filename (for caching)
      fstream myStream;       // C++ fstream file handle
      uInt64  myLength{0};    // length of zip file
      uInt16  myRomfiles{0};  // number of ROM files in central directory

      ZipEcd  myEcd;          // end of central directory

      ByteBuffer myCd;        // central directory raw data
      uInt64    myCdPos{0};   // position in central directory
      ZipHeader myHeader;     // current file header

      ByteBuffer myBuffer;    // buffer for decompression

      /** Constructor */
      explicit ZipFile(const string& filename);

      /** Open the file and set up the internal stream buffer*/
      bool open();

      /** Read the ZIP contents from the internal stream buffer */
      void initialize();

      /** Close previously opened internal stream buffer */
      void close();

      /** Read the ECD data */
      void readEcd();

      /** Read data from stream */
      bool readStream(const ByteBuffer& out, uInt64 offset, uInt64 length, uInt64& actual);

      /** Return the next entry in the ZIP file */
      const ZipHeader* nextFile();

      /** Decompress the most recently found file in the ZIP into target buffer */
      void decompress(const ByteBuffer& out, uInt64 length);

      /** Return the offset of the compressed data */
      uInt64 getCompressedDataOffset();

      /** Decompress type 0 data (which is uncompressed) */
      void decompressDataType0(uInt64 offset, const ByteBuffer& out, uInt64 length);

      /** Decompress type 8 data (which is deflated) */
      void decompressDataType8(uInt64 offset, const ByteBuffer& out, uInt64 length);
    };
    using ZipFilePtr = unique_ptr<ZipFile>;

    /** Classes to parse the ZIP metadata in an abstracted way */
    class ReaderBase
    {
      protected:
        explicit ReaderBase(const uInt8* const b) : myBuf{b} { }

        uInt8 read_byte(size_t offs) const
        {
          return myBuf[offs];
        }
        uInt16 read_word(size_t offs) const
        {
          return (static_cast<uInt16>(myBuf[offs + 1]) << 8) |
                 (static_cast<uInt16>(myBuf[offs + 0]) << 0);
        }
        uInt32 read_dword(std::size_t offs) const
        {
          return (static_cast<uInt32>(myBuf[offs + 3]) << 24) |
                 (static_cast<uInt32>(myBuf[offs + 2]) << 16) |
                 (static_cast<uInt32>(myBuf[offs + 1]) << 8)  |
                 (static_cast<uInt32>(myBuf[offs + 0]) << 0);
        }
        uInt64 read_qword(size_t offs) const
        {
          return (static_cast<uInt64>(myBuf[offs + 7]) << 56) |
                 (static_cast<uInt64>(myBuf[offs + 6]) << 48) |
                 (static_cast<uInt64>(myBuf[offs + 5]) << 40) |
                 (static_cast<uInt64>(myBuf[offs + 4]) << 32) |
                 (static_cast<uInt64>(myBuf[offs + 3]) << 24) |
                 (static_cast<uInt64>(myBuf[offs + 2]) << 16) |
                 (static_cast<uInt64>(myBuf[offs + 1]) << 8)  |
                 (static_cast<uInt64>(myBuf[offs + 0]) << 0);
        }
        string read_string(size_t offs, size_t len = string::npos) const
        {
          return string(reinterpret_cast<char const *>(myBuf + offs), len);
        }

      private:
        const uInt8* const myBuf{nullptr};
    };

    class LocalFileHeaderReader : public ReaderBase
    {
      public:
        explicit LocalFileHeaderReader(const uInt8* const b) : ReaderBase(b) { }

        uInt32  signature() const         { return read_dword(0x00); }
        uInt8   versionNeeded() const     { return read_byte(0x04);  }
        uInt8   osNeeded() const          { return read_byte(0x05);  }
        uInt16  generalFlag() const       { return read_word(0x06);  }
        uInt16  compressionMethod() const { return read_word(0x08);  }
        uInt16  modifiedTime() const      { return read_word(0x0a);  }
        uInt16  modifiedDate() const      { return read_word(0x0c);  }
        uInt32  crc32() const             { return read_dword(0x0e); }
        uInt32  compressedSize() const    { return read_dword(0x12); }
        uInt32  uncompressedSize() const  { return read_dword(0x16); }
        uInt16  filenameLength() const    { return read_word(0x1a);  }
        uInt16  extraFieldLength() const  { return read_word(0x1c);  }
        string  filename() const          { return read_string(0x1e, filenameLength()); }

        bool signatureCorrect() const  { return signature() == 0x04034b50; }

        size_t totalLength() const { return minimumLength() + filenameLength() + extraFieldLength(); }
        static size_t minimumLength() { return 0x1e; }
    };

    class CentralDirEntryReader : public ReaderBase
    {
      public:
        explicit CentralDirEntryReader(const uInt8* const b) : ReaderBase(b) { }

        uInt32 signature() const          { return read_dword(0x00); }
        uInt8  versionCreated() const     { return read_byte(0x04);  }
        uInt8  osCreated() const          { return read_byte(0x05);  }
        uInt8  versionNeeded() const      { return read_byte(0x06);  }
        uInt8  osNeeded() const           { return read_byte(0x07);  }
        uInt16 generalFlag() const        { return read_word(0x08);  }
        uInt16 compressionMethod() const  { return read_word(0x0a);  }
        uInt16 modifiedTime() const       { return read_word(0x0c);  }
        uInt16 modifiedDate() const       { return read_word(0x0e);  }
        uInt32 crc32() const              { return read_dword(0x10); }
        uInt32 compressedSize() const     { return read_dword(0x14); }
        uInt32 uncompressedSize() const   { return read_dword(0x18); }
        uInt16 filenameLength() const     { return read_word(0x1c);  }
        uInt16 extraFieldLength() const   { return read_word(0x1e);  }
        uInt16 fileCommentLength() const  { return read_word(0x20);  }
        uInt16 startDisk() const          { return read_word(0x22);  }
        uInt16 intFileAttr() const        { return read_word(0x24);  }
        uInt32 extFileAttr() const        { return read_dword(0x26); }
        uInt32 headerOffset() const       { return read_dword(0x2a); }
        string filename() const           { return read_string(0x2e, filenameLength()); }
        string fileComment() const        { return read_string(0x2e + filenameLength() + extraFieldLength(), fileCommentLength()); }

        bool signatureCorrect() const { return signature() == 0x02014b50; }

        size_t totalLength() const { return minimumLength() + filenameLength() + extraFieldLength() + fileCommentLength(); }
        static size_t minimumLength() { return 0x2e; }
    };

    class EcdReader : public ReaderBase
    {
      public:
        explicit EcdReader(const uInt8* const b) : ReaderBase(b) { }

        uInt32 signature() const       { return read_dword(0x00); }
        uInt16 thisDiskNo() const      { return read_word(0x04);  }
        uInt16 dirStartDisk() const    { return read_word(0x06);  }
        uInt16 dirDiskEntries() const  { return read_word(0x08);  }
        uInt16 dirTotalEntries() const { return read_word(0x0a);  }
        uInt32 dirSize() const         { return read_dword(0x0c); }
        uInt32 dirOffset() const       { return read_dword(0x10); }
        uInt16 commentLength() const   { return read_word(0x14);  }
        string comment() const         { return read_string(0x16, commentLength()); }

        bool signatureCorrect() const  { return signature() == 0x06054b50; }

        size_t totalLength() const { return minimumLength() + commentLength(); }
        static size_t minimumLength() { return 0x16; }
    };

    class GeneralFlagReader
    {
      public:
        explicit GeneralFlagReader(uInt16 val) : myValue{val} { }

        bool   encrypted() const           { return static_cast<bool>(myValue & 0x0001); }
        bool   implode8kDict() const       { return static_cast<bool>(myValue & 0x0002); }
        bool   implode3Trees() const       { return static_cast<bool>(myValue & 0x0004); }
        uInt32 deflateOption() const       { return static_cast<uInt32>((myValue >> 1) & 0x0003); }
        bool   lzmaEosMark() const         { return static_cast<bool>(myValue & 0x0002); }
        bool   useDescriptor() const       { return static_cast<bool>(myValue & 0x0008); }
        bool   patchData() const           { return static_cast<bool>(myValue & 0x0020); }
        bool   strongEncryption() const    { return static_cast<bool>(myValue & 0x0040); }
        bool   utf8Encoding() const        { return static_cast<bool>(myValue & 0x0800); }
        bool   directoryEncryption() const { return static_cast<bool>(myValue & 0x2000); }

      private:
        uInt16 myValue{0};
    };

  private:
    /** Get message for given ZipError enumeration */
    static string errorMessage(ZipError err);

    /** Search cache for given ZIP file */
    ZipFilePtr findCached(const string& filename);

    /** Close a ZIP file and add it to the cache */
    void addToCache();

  private:
    static constexpr size_t DECOMPRESS_BUFSIZE = 128_KB;
    static constexpr size_t CACHE_SIZE = 16; // number of open files to cache

    ZipFilePtr myZip;
    std::array<ZipFilePtr, CACHE_SIZE> myZipCache;

  private:
    // Following constructors and assignment operators not supported
    ZipHandler(const ZipHandler&) = delete;
    ZipHandler(ZipHandler&&) = delete;
    ZipHandler& operator=(const ZipHandler&) = delete;
    ZipHandler& operator=(ZipHandler&&) = delete;
};

#endif  /* ZIP_HANDLER_HXX */

#endif  /* ZIP_SUPPORT */
