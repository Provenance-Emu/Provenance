// OffsetStream.cpp

#include "StdAfx.h"

#include "../../Common/Defs.h"

#include "OffsetStream.h"

HRESULT COffsetOutStream::Init(IOutStream *stream, UInt64 offset)
{
  _offset = offset;
  _stream = stream;
  return _stream->Seek(offset, STREAM_SEEK_SET, NULL);
}

STDMETHODIMP COffsetOutStream::Write(const void *data, UInt32 size, UInt32 *processedSize)
{
  return _stream->Write(data, size, processedSize);
}

STDMETHODIMP COffsetOutStream::Seek(Int64 offset, UInt32 seekOrigin, UInt64 *newPosition)
{
  UInt64 absoluteNewPosition;
  if (seekOrigin == STREAM_SEEK_SET)
  {
    if (offset < 0)
      return HRESULT_WIN32_ERROR_NEGATIVE_SEEK;
    offset += _offset;
  }
  HRESULT result = _stream->Seek(offset, seekOrigin, &absoluteNewPosition);
  if (newPosition)
    *newPosition = absoluteNewPosition - _offset;
  return result;
}

STDMETHODIMP COffsetOutStream::SetSize(UInt64 newSize)
{
  return _stream->SetSize(_offset + newSize);
}
