// LzmaEncoder.cpp

#include "StdAfx.h"

#include "../../../C/Alloc.h"

#include "../Common/CWrappers.h"
#include "../Common/StreamUtils.h"

#include "LzmaEncoder.h"

namespace NCompress {
namespace NLzma {

CEncoder::CEncoder()
{
  _encoder = NULL;
  _encoder = LzmaEnc_Create(&g_Alloc);
  if (!_encoder)
    throw 1;
}

CEncoder::~CEncoder()
{
  if (_encoder)
    LzmaEnc_Destroy(_encoder, &g_Alloc, &g_BigAlloc);
}

static inline wchar_t GetUpperChar(wchar_t c)
{
  if (c >= 'a' && c <= 'z')
    c -= 0x20;
  return c;
}

static int ParseMatchFinder(const wchar_t *s, int *btMode, int *numHashBytes)
{
  wchar_t c = GetUpperChar(*s++);
  if (c == L'H')
  {
    if (GetUpperChar(*s++) != L'C')
      return 0;
    int numHashBytesLoc = (int)(*s++ - L'0');
    if (numHashBytesLoc < 4 || numHashBytesLoc > 4)
      return 0;
    if (*s != 0)
      return 0;
    *btMode = 0;
    *numHashBytes = numHashBytesLoc;
    return 1;
  }

  if (c != L'B')
    return 0;
  if (GetUpperChar(*s++) != L'T')
    return 0;
  int numHashBytesLoc = (int)(*s++ - L'0');
  if (numHashBytesLoc < 2 || numHashBytesLoc > 4)
    return 0;
  if (*s != 0)
    return 0;
  *btMode = 1;
  *numHashBytes = numHashBytesLoc;
  return 1;
}

#define SET_PROP_32(_id_, _dest_) case NCoderPropID::_id_: ep._dest_ = v; break;

HRESULT SetLzmaProp(PROPID propID, const PROPVARIANT &prop, CLzmaEncProps &ep)
{
  if (propID == NCoderPropID::kMatchFinder)
  {
    if (prop.vt != VT_BSTR)
      return E_INVALIDARG;
    return ParseMatchFinder(prop.bstrVal, &ep.btMode, &ep.numHashBytes) ? S_OK : E_INVALIDARG;
  }
  if (propID > NCoderPropID::kReduceSize)
    return S_OK;
  if (propID == NCoderPropID::kReduceSize)
  {
    if (prop.vt == VT_UI8)
      ep.reduceSize = prop.uhVal.QuadPart;
    return S_OK;
  }
  if (prop.vt != VT_UI4)
    return E_INVALIDARG;
  UInt32 v = prop.ulVal;
  switch (propID)
  {
    case NCoderPropID::kDefaultProp: if (v > 31) return E_INVALIDARG; ep.dictSize = (UInt32)1 << (unsigned)v; break;
    SET_PROP_32(kLevel, level)
    SET_PROP_32(kNumFastBytes, fb)
    SET_PROP_32(kMatchFinderCycles, mc)
    SET_PROP_32(kAlgorithm, algo)
    SET_PROP_32(kDictionarySize, dictSize)
    SET_PROP_32(kPosStateBits, pb)
    SET_PROP_32(kLitPosBits, lp)
    SET_PROP_32(kLitContextBits, lc)
    SET_PROP_32(kNumThreads, numThreads)
    default: return E_INVALIDARG;
  }
  return S_OK;
}

STDMETHODIMP CEncoder::SetCoderProperties(const PROPID *propIDs,
    const PROPVARIANT *coderProps, UInt32 numProps)
{
  CLzmaEncProps props;
  LzmaEncProps_Init(&props);

  for (UInt32 i = 0; i < numProps; i++)
  {
    const PROPVARIANT &prop = coderProps[i];
    PROPID propID = propIDs[i];
    switch (propID)
    {
      case NCoderPropID::kEndMarker:
        if (prop.vt != VT_BOOL) return E_INVALIDARG; props.writeEndMark = (prop.boolVal != VARIANT_FALSE); break;
      default:
        RINOK(SetLzmaProp(propID, prop, props));
    }
  }
  return SResToHRESULT(LzmaEnc_SetProps(_encoder, &props));
}

STDMETHODIMP CEncoder::WriteCoderProperties(ISequentialOutStream *outStream)
{
  Byte props[LZMA_PROPS_SIZE];
  size_t size = LZMA_PROPS_SIZE;
  RINOK(LzmaEnc_WriteProperties(_encoder, props, &size));
  return WriteStream(outStream, props, size);
}

STDMETHODIMP CEncoder::Code(ISequentialInStream *inStream, ISequentialOutStream *outStream,
    const UInt64 * /* inSize */, const UInt64 * /* outSize */, ICompressProgressInfo *progress)
{
  CSeqInStreamWrap inWrap(inStream);
  CSeqOutStreamWrap outWrap(outStream);
  CCompressProgressWrap progressWrap(progress);

  SRes res = LzmaEnc_Encode(_encoder, &outWrap.p, &inWrap.p, progress ? &progressWrap.p : NULL, &g_Alloc, &g_BigAlloc);
  _inputProcessed = inWrap.Processed;
  if (res == SZ_ERROR_READ && inWrap.Res != S_OK)
    return inWrap.Res;
  if (res == SZ_ERROR_WRITE && outWrap.Res != S_OK)
    return outWrap.Res;
  if (res == SZ_ERROR_PROGRESS && progressWrap.Res != S_OK)
    return progressWrap.Res;
  return SResToHRESULT(res);
}

}}
