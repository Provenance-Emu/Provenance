// LzmaHandler.cpp

#include "StdAfx.h"

#include "../../../C/CpuArch.h"

#include "../../Common/ComTry.h"
#include "../../Common/IntToString.h"

#include "../../Windows/PropVariant.h"

#include "../Common/FilterCoder.h"
#include "../Common/ProgressUtils.h"
#include "../Common/RegisterArc.h"
#include "../Common/StreamUtils.h"

#include "../Compress/BcjCoder.h"
#include "../Compress/LzmaDecoder.h"

#include "Common/DummyOutStream.h"

using namespace NWindows;

namespace NArchive {
namespace NLzma {

static bool CheckDicSize(const Byte *p)
{
  UInt32 dicSize = GetUi32(p);
  if (dicSize == 1)
    return true;
  for (unsigned i = 0; i <= 30; i++)
    if (dicSize == ((UInt32)2 << i) || dicSize == ((UInt32)3 << i))
      return true;
  return (dicSize == 0xFFFFFFFF);
}

static const Byte kProps[] =
{
  kpidSize,
  kpidPackSize,
  kpidMethod
};

static const Byte kArcProps[] =
{
  kpidNumStreams
};

struct CHeader
{
  UInt64 Size;
  Byte FilterID;
  Byte LzmaProps[5];

  UInt32 GetDicSize() const { return GetUi32(LzmaProps + 1); }
  bool HasSize() const { return (Size != (UInt64)(Int64)-1); }
  bool Parse(const Byte *buf, bool isThereFilter);
};

bool CHeader::Parse(const Byte *buf, bool isThereFilter)
{
  FilterID = 0;
  if (isThereFilter)
    FilterID = buf[0];
  const Byte *sig = buf + (isThereFilter ? 1 : 0);
  for (int i = 0; i < 5; i++)
    LzmaProps[i] = sig[i];
  Size = GetUi64(sig + 5);
  return
    LzmaProps[0] < 5 * 5 * 9 &&
    FilterID < 2 &&
    (!HasSize() || Size < ((UInt64)1 << 56))
    && CheckDicSize(LzmaProps + 1);
}

class CDecoder
{
  CMyComPtr<ISequentialOutStream> _bcjStream;
  CFilterCoder *_filterCoder;
  CMyComPtr<ICompressCoder> _lzmaDecoder;
public:
  NCompress::NLzma::CDecoder *_lzmaDecoderSpec;

  ~CDecoder();
  HRESULT Create(bool filtered, ISequentialInStream *inStream);

  HRESULT Code(const CHeader &header, ISequentialOutStream *outStream, ICompressProgressInfo *progress);

  UInt64 GetInputProcessedSize() const { return _lzmaDecoderSpec->GetInputProcessedSize(); }

  void ReleaseInStream() { if (_lzmaDecoder) _lzmaDecoderSpec->ReleaseInStream(); }

  HRESULT ReadInput(Byte *data, UInt32 size, UInt32 *processedSize)
    { return _lzmaDecoderSpec->ReadFromInputStream(data, size, processedSize); }
};

HRESULT CDecoder::Create(bool filteredMode, ISequentialInStream *inStream)
{
  if (!_lzmaDecoder)
  {
    _lzmaDecoderSpec = new NCompress::NLzma::CDecoder;
    _lzmaDecoderSpec->FinishStream = true;
    _lzmaDecoder = _lzmaDecoderSpec;
  }

  if (filteredMode)
  {
    if (!_bcjStream)
    {
      _filterCoder = new CFilterCoder(false);
      CMyComPtr<ICompressCoder> coder = _filterCoder;
      _filterCoder->Filter = new NCompress::NBcj::CCoder(false);
      _bcjStream = _filterCoder;
    }
  }

  return _lzmaDecoderSpec->SetInStream(inStream);
}

CDecoder::~CDecoder()
{
  ReleaseInStream();
}

HRESULT CDecoder::Code(const CHeader &header, ISequentialOutStream *outStream,
    ICompressProgressInfo *progress)
{
  if (header.FilterID > 1)
    return E_NOTIMPL;

  {
    CMyComPtr<ICompressSetDecoderProperties2> setDecoderProperties;
    _lzmaDecoder.QueryInterface(IID_ICompressSetDecoderProperties2, &setDecoderProperties);
    if (!setDecoderProperties)
      return E_NOTIMPL;
    RINOK(setDecoderProperties->SetDecoderProperties2(header.LzmaProps, 5));
  }

  bool filteredMode = (header.FilterID == 1);

  if (filteredMode)
  {
    RINOK(_filterCoder->SetOutStream(outStream));
    outStream = _bcjStream;
    RINOK(_filterCoder->SetOutStreamSize(NULL));
  }

  const UInt64 *Size = header.HasSize() ? &header.Size : NULL;
  HRESULT res = _lzmaDecoderSpec->CodeResume(outStream, Size, progress);

  if (filteredMode)
  {
    {
      HRESULT res2 = _filterCoder->OutStreamFinish();
      if (res == S_OK)
        res = res2;
    }
    HRESULT res2 = _filterCoder->ReleaseOutStream();
    if (res == S_OK)
      res = res2;
  }
  
  RINOK(res);

  if (header.HasSize())
    if (_lzmaDecoderSpec->GetOutputProcessedSize() != header.Size)
      return S_FALSE;

  return S_OK;
}


class CHandler:
  public IInArchive,
  public IArchiveOpenSeq,
  public CMyUnknownImp
{
  CHeader _header;
  bool _lzma86;
  CMyComPtr<IInStream> _stream;
  CMyComPtr<ISequentialInStream> _seqStream;
  
  bool _isArc;
  bool _needSeekToStart;
  bool _dataAfterEnd;
  bool _needMoreInput;

  bool _packSize_Defined;
  bool _unpackSize_Defined;
  bool _numStreams_Defined;

  bool _unsupported;
  bool _dataError;

  UInt64 _packSize;
  UInt64 _unpackSize;
  UInt64 _numStreams;

public:
  MY_UNKNOWN_IMP2(IInArchive, IArchiveOpenSeq)

  INTERFACE_IInArchive(;)
  STDMETHOD(OpenSeq)(ISequentialInStream *stream);

  CHandler(bool lzma86) { _lzma86 = lzma86; }

  unsigned GetHeaderSize() const { return 5 + 8 + (_lzma86 ? 1 : 0); }

};

IMP_IInArchive_Props
IMP_IInArchive_ArcProps

STDMETHODIMP CHandler::GetArchiveProperty(PROPID propID, PROPVARIANT *value)
{
  NCOM::CPropVariant prop;
  switch (propID)
  {
    case kpidPhySize: if (_packSize_Defined) prop = _packSize; break;
    case kpidNumStreams: if (_numStreams_Defined) prop = _numStreams; break;
    case kpidUnpackSize: if (_unpackSize_Defined) prop = _unpackSize; break;
    case kpidErrorFlags:
    {
      UInt32 v = 0;
      if (!_isArc) v |= kpv_ErrorFlags_IsNotArc;;
      if (_needMoreInput) v |= kpv_ErrorFlags_UnexpectedEnd;
      if (_dataAfterEnd) v |= kpv_ErrorFlags_DataAfterEnd;
      if (_unsupported) v |= kpv_ErrorFlags_UnsupportedMethod;
      if (_dataError) v |= kpv_ErrorFlags_DataError;
      prop = v;
    }
  }
  prop.Detach(value);
  return S_OK;
}

STDMETHODIMP CHandler::GetNumberOfItems(UInt32 *numItems)
{
  *numItems = 1;
  return S_OK;
}

static void DictSizeToString(UInt32 value, char *s)
{
  for (int i = 0; i <= 31; i++)
    if (((UInt32)1 << i) == value)
    {
      ::ConvertUInt32ToString(i, s);
      return;
    }
  char c = 'b';
       if ((value & ((1 << 20) - 1)) == 0) { value >>= 20; c = 'm'; }
  else if ((value & ((1 << 10) - 1)) == 0) { value >>= 10; c = 'k'; }
  ::ConvertUInt32ToString(value, s);
  s += MyStringLen(s);
  *s++ = c;
  *s = 0;
}

STDMETHODIMP CHandler::GetProperty(UInt32 /* index */, PROPID propID, PROPVARIANT *value)
{
  NCOM::CPropVariant prop;
  switch (propID)
  {
    case kpidSize: if (_stream && _header.HasSize()) prop = _header.Size; break;
    case kpidPackSize: if (_packSize_Defined) prop = _packSize; break;
    case kpidMethod:
      if (_stream)
      {
        char sz[64];
        char *s = sz;
        if (_header.FilterID != 0)
          s = MyStpCpy(s, "BCJ ");
        s = MyStpCpy(s, "LZMA:");
        DictSizeToString(_header.GetDicSize(), s);
        prop = sz;
      }
      break;
  }
  prop.Detach(value);
  return S_OK;
}

API_FUNC_static_IsArc IsArc_Lzma(const Byte *p, size_t size)
{
  const UInt32 kHeaderSize = 1 + 4 + 8;
  if (size < kHeaderSize)
    return k_IsArc_Res_NEED_MORE;
  if (p[0] >= 5 * 5 * 9)
    return k_IsArc_Res_NO;
  UInt64 unpackSize = GetUi64(p + 1 + 4);
  if (unpackSize != (UInt64)(Int64)-1)
  {
    if (size >= ((UInt64)1 << 56))
      return k_IsArc_Res_NO;
  }
  if (unpackSize != 0)
  {
    if (size < kHeaderSize + 2)
      return k_IsArc_Res_NEED_MORE;
    if (p[kHeaderSize] != 0)
      return k_IsArc_Res_NO;
    if (unpackSize != (UInt64)(Int64)-1)
    {
      if ((p[kHeaderSize + 1] & 0x80) != 0)
        return k_IsArc_Res_NO;
    }
  }
  if (!CheckDicSize(p + 1))
    // return k_IsArc_Res_YES_LOW_PROB;
    return k_IsArc_Res_NO;
  return k_IsArc_Res_YES;
}
}

API_FUNC_static_IsArc IsArc_Lzma86(const Byte *p, size_t size)
{
  if (size < 1)
    return k_IsArc_Res_NEED_MORE;
  Byte filterID = p[0];
  if (filterID != 0 && filterID != 1)
    return k_IsArc_Res_NO;
  return IsArc_Lzma(p + 1, size - 1);
}
}

STDMETHODIMP CHandler::Open(IInStream *inStream, const UInt64 *, IArchiveOpenCallback *)
{
  Close();
  
  const UInt32 kBufSize = 1 + 5 + 8 + 2;
  Byte buf[kBufSize];
  
  RINOK(ReadStream_FALSE(inStream, buf, kBufSize));
  
  if (!_header.Parse(buf, _lzma86))
    return S_FALSE;
  const Byte *start = buf + GetHeaderSize();
  if (start[0] != 0 /* || (start[1] & 0x80) != 0 */ ) // empty stream with EOS is not 0x80
    return S_FALSE;
  
  RINOK(inStream->Seek(0, STREAM_SEEK_END, &_packSize));
  if (_packSize >= 24 && _header.Size == 0 && _header.FilterID == 0 && _header.LzmaProps[0] == 0)
    return S_FALSE;
  _isArc = true;
  _stream = inStream;
  _seqStream = inStream;
  _needSeekToStart = true;
  return S_OK;
}

STDMETHODIMP CHandler::OpenSeq(ISequentialInStream *stream)
{
  Close();
  _isArc = true;
  _seqStream = stream;
  return S_OK;
}

STDMETHODIMP CHandler::Close()
{
  _isArc = false;
  _packSize_Defined = false;
  _unpackSize_Defined = false;
  _numStreams_Defined = false;

  _dataAfterEnd = false;
  _needMoreInput = false;
  _unsupported = false;
  _dataError = false;

  _packSize = 0;

  _needSeekToStart = false;

  _stream.Release();
  _seqStream.Release();
   return S_OK;
}

class CCompressProgressInfoImp:
  public ICompressProgressInfo,
  public CMyUnknownImp
{
  CMyComPtr<IArchiveOpenCallback> Callback;
public:
  UInt64 Offset;
 
  MY_UNKNOWN_IMP1(ICompressProgressInfo)
  STDMETHOD(SetRatioInfo)(const UInt64 *inSize, const UInt64 *outSize);
  void Init(IArchiveOpenCallback *callback) { Callback = callback; }
};

STDMETHODIMP CCompressProgressInfoImp::SetRatioInfo(const UInt64 *inSize, const UInt64 * /* outSize */)
{
  if (Callback)
  {
    UInt64 files = 0;
    UInt64 value = Offset + *inSize;
    return Callback->SetCompleted(&files, &value);
  }
  return S_OK;
}

STDMETHODIMP CHandler::Extract(const UInt32 *indices, UInt32 numItems,
    Int32 testMode, IArchiveExtractCallback *extractCallback)
{
  COM_TRY_BEGIN

  if (numItems == 0)
    return S_OK;
  if (numItems != (UInt32)(Int32)-1 && (numItems != 1 || indices[0] != 0))
    return E_INVALIDARG;

  if (_packSize_Defined)
    extractCallback->SetTotal(_packSize);
    
  
  CMyComPtr<ISequentialOutStream> realOutStream;
  Int32 askMode = testMode ?
      NExtract::NAskMode::kTest :
      NExtract::NAskMode::kExtract;
  RINOK(extractCallback->GetStream(0, &realOutStream, askMode));
  if (!testMode && !realOutStream)
    return S_OK;
  
  extractCallback->PrepareOperation(askMode);

  CDummyOutStream *outStreamSpec = new CDummyOutStream;
  CMyComPtr<ISequentialOutStream> outStream(outStreamSpec);
  outStreamSpec->SetStream(realOutStream);
  outStreamSpec->Init();
  realOutStream.Release();

  CLocalProgress *lps = new CLocalProgress;
  CMyComPtr<ICompressProgressInfo> progress = lps;
  lps->Init(extractCallback, true);

  if (_needSeekToStart)
  {
    if (!_stream)
      return E_FAIL;
    RINOK(_stream->Seek(0, STREAM_SEEK_SET, NULL));
  }
  else
    _needSeekToStart = true;

  CDecoder decoder;
  HRESULT result = decoder.Create(_lzma86, _seqStream);
  RINOK(result);
 
  bool firstItem = true;

  UInt64 packSize = 0;
  UInt64 unpackSize = 0;
  UInt64 numStreams = 0;

  bool dataAfterEnd = false;
  
  for (;;)
  {
    lps->InSize = packSize;
    lps->OutSize = unpackSize;
    RINOK(lps->SetCur());

    const UInt32 kBufSize = 1 + 5 + 8;
    Byte buf[kBufSize];
    const UInt32 headerSize = GetHeaderSize();
    UInt32 processed;
    RINOK(decoder.ReadInput(buf, headerSize, &processed));
    if (processed != headerSize)
    {
      if (processed != 0)
        dataAfterEnd = true;
      break;
    }
  
    CHeader st;
    if (!st.Parse(buf, _lzma86))
    {
      dataAfterEnd = true;
      break;
    }
    numStreams++;
    firstItem = false;

    result = decoder.Code(st, outStream, progress);

    packSize = decoder.GetInputProcessedSize();
    unpackSize = outStreamSpec->GetSize();
    
    if (result == E_NOTIMPL)
    {
      _unsupported = true;
      result = S_FALSE;
      break;
    }
    if (result == S_FALSE)
      break;
    RINOK(result);
  }

  if (firstItem)
  {
    _isArc = false;
    result = S_FALSE;
  }
  else if (result == S_OK || result == S_FALSE)
  {
    if (dataAfterEnd)
      _dataAfterEnd = true;
    else if (decoder._lzmaDecoderSpec->NeedMoreInput)
      _needMoreInput = true;

    _packSize = packSize;
    _unpackSize = unpackSize;
    _numStreams = numStreams;
  
    _packSize_Defined = true;
    _unpackSize_Defined = true;
    _numStreams_Defined = true;
  }
  
  Int32 opResult = NExtract::NOperationResult::kOK;

  if (!_isArc)
    opResult = NExtract::NOperationResult::kIsNotArc;
  else if (_needMoreInput)
    opResult = NExtract::NOperationResult::kUnexpectedEnd;
  else if (_unsupported)
    opResult = NExtract::NOperationResult::kUnsupportedMethod;
  else if (_dataAfterEnd)
    opResult = NExtract::NOperationResult::kDataAfterEnd;
  else if (result == S_FALSE)
    opResult = NExtract::NOperationResult::kDataError;
  else if (result == S_OK)
    opResult = NExtract::NOperationResult::kOK;
  else
    return result;

  outStream.Release();
  return extractCallback->SetOperationResult(opResult);

  COM_TRY_END
}

namespace NLzmaAr {

// 2, { 0x5D, 0x00 },

REGISTER_ARC_I_CLS_NO_SIG(
  CHandler(false),
  "lzma", "lzma", 0, 0xA,
  0,
  NArcInfoFlags::kStartOpen |
  NArcInfoFlags::kKeepName,
  IsArc_Lzma)
 
}

namespace NLzma86Ar {

REGISTER_ARC_I_CLS_NO_SIG(
  CHandler(true),
  "lzma86", "lzma86", 0, 0xB,
  0,
  NArcInfoFlags::kKeepName,
  IsArc_Lzma86)
 
}

}}
