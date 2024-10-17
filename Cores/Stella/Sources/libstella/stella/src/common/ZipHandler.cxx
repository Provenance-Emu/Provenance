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

#include <zlib.h>

#include "Bankswitch.hxx"
#include "ZipHandler.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ZipHandler::open(const string& filename)
{
  // Close already open file (if any) and add to cache
  addToCache();

  // Ensure we start with a nullptr result
  myZip.reset();

  ZipFilePtr ptr = findCached(filename);
  if(ptr)
  {
    // Only a previously used entry will exist in the cache, so we know it's valid
    myZip = std::move(ptr);

    // Was already initialized; we just need to re-open it
    if(!myZip->open())
      throw runtime_error(errorMessage(ZipError::FILE_ERROR));
  }
  else
  {
    // Allocate memory for the ZipFile structure
    try        { ptr = make_unique<ZipFile>(filename); }
    catch(...) { throw runtime_error(errorMessage(ZipError::OUT_OF_MEMORY)); }

    // Open the file and initialize it
    if(!ptr->open())
      throw runtime_error(errorMessage(ZipError::FILE_ERROR));
    ptr->initialize();

    myZip = std::move(ptr);

    // Count ROM files (we do it here so it will be cached)
    try
    {
      while(hasNext())
      {
        const auto& [name, size] = next();
        if(Bankswitch::isValidRomName(name))
          myZip->myRomfiles++;
      }
    }
    catch(...)
    {
      myZip->myRomfiles = 0;
    }
  }

  reset();  // Reset iterator to beginning for subsequent use
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ZipHandler::reset()
{
  // Reset the position and go from there
  if(myZip)
    myZip->myCdPos = 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ZipHandler::hasNext() const
{
  return myZip && (myZip->myCdPos < myZip->myEcd.cdSize);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
std::tuple<string, size_t> ZipHandler::next()
{
  if(hasNext())
  {
    const ZipHeader* const header = myZip->nextFile();
    if(!header)
      throw runtime_error(errorMessage(ZipError::FILE_CORRUPT));
    else if(header->uncompressedLength == 0)
      return next();
    else
      return {header->filename, header->uncompressedLength};
  }
  return {EmptyString, 0};
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt64 ZipHandler::decompress(ByteBuffer& image)
{
  if(myZip && myZip->myHeader.uncompressedLength > 0)
  {
    try
    {
      const uInt64 length = myZip->myHeader.uncompressedLength;
      image = make_unique<uInt8[]>(length);

      myZip->decompress(image, length);
      return length;
    }
    catch(const ZipError& err)
    {
      throw runtime_error(errorMessage(err));
    }
    catch(...)
    {
      throw runtime_error(errorMessage(ZipError::OUT_OF_MEMORY));
    }
  }
  else
    throw runtime_error("Invalid ZIP archive");
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string ZipHandler::errorMessage(ZipError err)
{
  static constexpr std::array<string_view, 10> zip_error_s = {
    "ZIP NONE",
    "ZIP OUT_OF_MEMORY",
    "ZIP FILE_ERROR",
    "ZIP BAD_SIGNATURE",
    "ZIP DECOMPRESS_ERROR",
    "ZIP FILE_TRUNCATED",
    "ZIP FILE_CORRUPT",
    "ZIP UNSUPPORTED",
    "ZIP LZMA_UNSUPPORTED",
    "ZIP BUFFER_TOO_SMALL"
  };
  return string{zip_error_s[static_cast<int>(err)]};
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ZipHandler::ZipFilePtr ZipHandler::findCached(const string& filename)
{
  for(auto& cache: myZipCache)
  {
    // If we have a valid entry and it matches our filename,
    // use it and remove from the cache
    if(cache && (filename == cache->myFilename))
    {
      ZipFilePtr result;
      std::swap(cache, result);
      return result;
    }
  }
  return {};
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ZipHandler::addToCache()
{
  if(myZip == nullptr)
    return;

  // Close the open file
  myZip->close();

  // Find the first nullptr entry in the cache
  size_t cachenum{0};
  for(cachenum = 0; cachenum < myZipCache.size(); ++cachenum)
    if(myZipCache[cachenum] == nullptr)
      break;

  // If no room left in the cache, free the bottommost entry
  if(cachenum == myZipCache.size())
  {
    cachenum--;
    myZipCache[cachenum].reset();
  }

  for( ; cachenum > 0; --cachenum)
    myZipCache[cachenum] = std::move(myZipCache[cachenum - 1]);
  myZipCache[0] = std::move(myZip);

#if 0
  cerr << "\nCACHE contents:\n";
    for(cachenum = 0; cachenum < myZipCache.size(); ++cachenum)
      if(myZipCache[cachenum] != nullptr)
        cerr << "  " << cachenum << " : " << myZipCache[cachenum]->filename << '\n';
  cerr << '\n';
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ZipHandler::ZipFile::ZipFile(const string& filename)
  : myFilename{filename},
    myBuffer{make_unique<uInt8[]>(DECOMPRESS_BUFSIZE)}
{
  std::fill(myBuffer.get(), myBuffer.get() + DECOMPRESS_BUFSIZE, 0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ZipHandler::ZipFile::open()
{
  myStream.open(myFilename, fstream::in | fstream::binary);
  if(!myStream.is_open())
  {
    myLength = 0;
    return false;
  }
  myStream.exceptions( std::ios_base::failbit | std::ios_base::badbit | std::ios_base::eofbit );
  myStream.seekg(0, std::ios::end);
  myLength = myStream.tellg();
  myStream.seekg(0, std::ios::beg);

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ZipHandler::ZipFile::initialize()
{
  // Read ecd data
  readEcd();

  // Verify that we can work with this zipfile (no disk spanning allowed)
  if(myEcd.diskNumber != myEcd.cdStartDiskNumber ||
     myEcd.cdDiskEntries != myEcd.cdTotalEntries)
    throw runtime_error(errorMessage(ZipError::UNSUPPORTED));

  // Allocate memory for the central directory
  try        { myCd = make_unique<uInt8[]>(myEcd.cdSize + 1); }
  catch(...) { throw runtime_error(errorMessage(ZipError::OUT_OF_MEMORY)); }

  // Read the central directory
  uInt64 read_length = 0;
  const bool success = readStream(myCd, myEcd.cdStartDiskOffset, myEcd.cdSize, read_length);
  if(!success)
    throw runtime_error(errorMessage(ZipError::FILE_ERROR));
  else if(read_length != myEcd.cdSize)
    throw runtime_error(errorMessage(ZipError::FILE_TRUNCATED));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ZipHandler::ZipFile::close()
{
  if(myStream.is_open())
    myStream.close();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ZipHandler::ZipFile::readEcd()
{
  uInt64 buflen = 1024;

  // We may need multiple tries
  while(buflen < 65536)
  {
    uInt64 read_length = 0;

    // Max out the buf length at the size of the file
    if(buflen > myLength)
      buflen = myLength;

    // Allocate buffer
    const ByteBuffer buffer = make_unique<uInt8[]>(buflen + 1);
    if(buffer == nullptr)
      throw runtime_error(errorMessage(ZipError::OUT_OF_MEMORY));

    // Read in one buffers' worth of data
    const bool success = readStream(buffer, myLength - buflen, buflen, read_length);
    if(!success || read_length != buflen)
      throw runtime_error(errorMessage(ZipError::FILE_ERROR));

    // Find the ECD signature
    Int32 offset = 0;
    for(offset = static_cast<Int32>(buflen - EcdReader::minimumLength()); offset >= 0; --offset)
    {
      const EcdReader reader(buffer.get() + offset);
      if(reader.signatureCorrect() && ((reader.totalLength() + offset) <= buflen))
        break;
    }

    // If we found it, fill out the data
    if(offset >= 0)
    {
      // Extract ECD info
      const EcdReader reader(buffer.get() + offset);
      myEcd.diskNumber        = reader.thisDiskNo();
      myEcd.cdStartDiskNumber = reader.dirStartDisk();
      myEcd.cdDiskEntries     = reader.dirDiskEntries();
      myEcd.cdTotalEntries    = reader.dirTotalEntries();
      myEcd.cdSize            = reader.dirSize();
      myEcd.cdStartDiskOffset = reader.dirOffset();
      return;
    }

    // Didn't find it; expand our search
    if(buflen < myLength)
      buflen *= 2;
    else
      throw runtime_error(errorMessage(ZipError::BAD_SIGNATURE));
  }
  throw runtime_error(errorMessage(ZipError::OUT_OF_MEMORY));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ZipHandler::ZipFile::readStream(const ByteBuffer& out, uInt64 offset,
                                     uInt64 length, uInt64& actual)
{
  try
  {
    myStream.seekg(offset);
    myStream.read(reinterpret_cast<char*>(out.get()), length);

    actual = myStream.gcount();
    return true;
  }
  catch(...)
  {
    return false;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const ZipHandler::ZipHeader* ZipHandler::ZipFile::nextFile()
{
  // Make sure we have enough data
  // If we're at or past the end, we're done
  const CentralDirEntryReader reader(myCd.get() + myCdPos);
  if(!reader.signatureCorrect() || ((myCdPos + reader.totalLength()) > myEcd.cdSize))
    return nullptr;

  // Extract file header info
  myHeader.versionCreated     = reader.versionCreated();
  myHeader.versionNeeded      = reader.versionNeeded();
  myHeader.bitFlag            = reader.generalFlag();
  myHeader.compression        = reader.compressionMethod();
  myHeader.crc                = reader.crc32();
  myHeader.compressedLength   = reader.compressedSize();
  myHeader.uncompressedLength = reader.uncompressedSize();
  myHeader.startDiskNumber    = reader.startDisk();
  myHeader.localHeaderOffset  = reader.headerOffset();
  myHeader.filename           = reader.filename();

  // Advance the position
  myCdPos += reader.totalLength();
  return &myHeader;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ZipHandler::ZipFile::decompress(const ByteBuffer& out, uInt64 length)
{
  // If we don't have enough buffer, error
  if(length < myHeader.uncompressedLength)
    throw runtime_error(errorMessage(ZipError::BUFFER_TOO_SMALL));

  // Make sure the info in the header aligns with what we know
  if(myHeader.startDiskNumber != myEcd.diskNumber)
    throw runtime_error(errorMessage(ZipError::UNSUPPORTED));

  // Get the compressed data offset
  const uInt64 offset = getCompressedDataOffset();

  // Handle compression types
  switch(myHeader.compression)
  {
    case 0:
      decompressDataType0(offset, out, length);
      break;

    case 8:
      decompressDataType8(offset, out, length);
      break;

    case 14:
      // FIXME - LZMA format not yet supported
      throw runtime_error(errorMessage(ZipError::LZMA_UNSUPPORTED));

    default:
      throw runtime_error(errorMessage(ZipError::UNSUPPORTED));
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt64 ZipHandler::ZipFile::getCompressedDataOffset()
{
  // Don't support a number of features
  const GeneralFlagReader flags(myHeader.bitFlag);
  if(myHeader.startDiskNumber != myEcd.diskNumber ||
     myHeader.versionNeeded > 63 || flags.patchData() ||
     flags.encrypted() || flags.strongEncryption())
    throw runtime_error(errorMessage(ZipError::UNSUPPORTED));

  // Read the fixed-sized part of the local file header
  uInt64 read_length = 0;
  const bool success = readStream(myBuffer, myHeader.localHeaderOffset, 0x1e, read_length);
  if(!success)
    throw runtime_error(errorMessage(ZipError::FILE_ERROR));
  else if(read_length != LocalFileHeaderReader::minimumLength())
    throw runtime_error(errorMessage(ZipError::FILE_TRUNCATED));

  // Compute the final offset
  const LocalFileHeaderReader reader(&myBuffer[0]);
  if(!reader.signatureCorrect())
    throw runtime_error(errorMessage(ZipError::BAD_SIGNATURE));

  return myHeader.localHeaderOffset + reader.totalLength();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ZipHandler::ZipFile::decompressDataType0(
    uInt64 offset, const ByteBuffer& out, uInt64 length)
{
  // The data is uncompressed; just read it
  uInt64 read_length = 0;
  const bool success = readStream(out, offset, myHeader.compressedLength, read_length);
  if(!success)
    throw runtime_error(errorMessage(ZipError::FILE_ERROR));
  else if(read_length != myHeader.compressedLength)
    throw runtime_error(errorMessage(ZipError::FILE_TRUNCATED));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void ZipHandler::ZipFile::decompressDataType8(
    uInt64 offset, const ByteBuffer& out, uInt64 length)
{
  uInt64 input_remaining = myHeader.compressedLength;

  // Reset the stream
  z_stream stream{};
  stream.zalloc = Z_NULL;
  stream.zfree = Z_NULL;
  stream.opaque = Z_NULL;
  stream.avail_in = 0;
  stream.next_out = reinterpret_cast<Bytef *>(out.get());
  stream.avail_out = static_cast<uInt32>(length);

  // Initialize the decompressor
  int zerr = inflateInit2(&stream, -MAX_WBITS);
  if(zerr != Z_OK)
    throw runtime_error(errorMessage(ZipError::DECOMPRESS_ERROR));

  // Loop until we're done
  for(;;)
  {
    // Read in the next chunk of data
    uInt64 read_length = 0;
    const bool success = readStream(myBuffer, offset,
          std::min(input_remaining, static_cast<uInt64>(sizeof(myBuffer.get()))), read_length);
    if(!success)
    {
      inflateEnd(&stream);
      throw runtime_error(errorMessage(ZipError::FILE_ERROR));
    }
    offset += read_length;

    // If we read nothing, but still have data left, the file is truncated
    if(read_length == 0 && input_remaining > 0)
    {
      inflateEnd(&stream);
      throw runtime_error(errorMessage(ZipError::FILE_TRUNCATED));
    }

    // Fill out the input data
    stream.next_in = myBuffer.get();
    stream.avail_in = static_cast<uInt32>(read_length);
    input_remaining -= read_length;

    // Add a dummy byte at end of compressed data
    if(input_remaining == 0)
      stream.avail_in++;

    // Now inflate
    zerr = inflate(&stream, Z_NO_FLUSH);
    if(zerr == Z_STREAM_END)
      break;
    else if(zerr != Z_OK)
    {
      inflateEnd(&stream);
      throw runtime_error(errorMessage(ZipError::DECOMPRESS_ERROR));
    }
  }

  // Finish decompression
  zerr = inflateEnd(&stream);
  if(zerr != Z_OK)
    throw runtime_error(errorMessage(ZipError::DECOMPRESS_ERROR));

  // If anything looks funny, report an error
  if(stream.avail_out > 0 || input_remaining > 0)
    throw runtime_error(errorMessage(ZipError::DECOMPRESS_ERROR));
}

#endif  /* ZIP_SUPPORT */
