// InOutTempBuffer.h

#ifndef __IN_OUT_TEMP_BUFFER_H
#define __IN_OUT_TEMP_BUFFER_H

#include "../../Common/MyCom.h"
#if !defined(__APPLE__)
#include "../../Windows/FileDir.h"
#endif

#include "../IStream.h"

#if defined(__APPLE__)
#include "../../Common/C_FileIO.h"
#endif

class CInOutTempBuffer final
{
#if defined(__APPLE__)
    NC::NFile::NIO::COutFile _outFile;
#else
  NWindows::NFile::NDir::CTempFile _tempFile;
  NWindows::NFile::NIO::COutFile _outFile;
#endif
  Byte *_buf;
  size_t _bufPos;
  UInt64 _size;
  UInt32 _crc;
  bool _tempFileCreated;

  bool WriteToFile(const void *data, UInt32 size);
public:
  CInOutTempBuffer();
  ~CInOutTempBuffer();
  void Create();

  void InitWriting();
  bool Write(const void *data, UInt32 size);

  HRESULT WriteToStream(ISequentialOutStream *stream);
  UInt64 GetDataSize() const { return _size; }
};

/*
class CSequentialOutTempBufferImp:
  public ISequentialOutStream,
  public CMyUnknownImp
{
  CInOutTempBuffer *_buf;
public:
  void Init(CInOutTempBuffer *buffer)  { _buf = buffer; }
  MY_UNKNOWN_IMP

  STDMETHOD(Write)(const void *data, UInt32 size, UInt32 *processedSize);
};
*/

#endif
