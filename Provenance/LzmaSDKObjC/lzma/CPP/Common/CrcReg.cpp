// CrcReg.cpp

#include "StdAfx.h"

#include "../../C/7zCrc.h"
#include "../../C/CpuArch.h"

#include "../Common/MyCom.h"

#include "../7zip/Common/RegisterCodec.h"

EXTERN_C_BEGIN

typedef UInt32 (MY_FAST_CALL *CRC_FUNC)(UInt32 v, const void *data, size_t size, const UInt32 *table);

UInt32 MY_FAST_CALL CrcUpdateT1(UInt32 v, const void *data, size_t size, const UInt32 *table);

extern CRC_FUNC g_CrcUpdate;
extern CRC_FUNC g_CrcUpdateT8;
extern CRC_FUNC g_CrcUpdateT4;

EXTERN_C_END

class CCrcHasher:
  public IHasher,
  public ICompressSetCoderProperties,
  public CMyUnknownImp
{
  UInt32 _crc;
  CRC_FUNC _updateFunc;
  Byte mtDummy[1 << 7];
  
  bool SetFunctions(UInt32 tSize);
public:
  CCrcHasher(): _crc(CRC_INIT_VAL) { SetFunctions(0); }

  MY_UNKNOWN_IMP2(IHasher, ICompressSetCoderProperties)
  INTERFACE_IHasher(;)
  STDMETHOD(SetCoderProperties)(const PROPID *propIDs, const PROPVARIANT *props, UInt32 numProps);
};

bool CCrcHasher::SetFunctions(UInt32 tSize)
{
  _updateFunc = g_CrcUpdate;
  
  if (tSize == 1)
    _updateFunc = CrcUpdateT1;
  else if (tSize == 4)
  {
    if (g_CrcUpdateT4)
      _updateFunc = g_CrcUpdateT4;
    else
      return false;
  }
  else if (tSize == 8)
  {
    if (g_CrcUpdateT8)
      _updateFunc = g_CrcUpdateT8;
    else
      return false;
  }
  
  return true;
}

STDMETHODIMP CCrcHasher::SetCoderProperties(const PROPID *propIDs, const PROPVARIANT *coderProps, UInt32 numProps)
{
  for (UInt32 i = 0; i < numProps; i++)
  {
    const PROPVARIANT &prop = coderProps[i];
    if (propIDs[i] == NCoderPropID::kDefaultProp)
    {
      if (prop.vt != VT_UI4)
        return E_INVALIDARG;
      if (!SetFunctions(prop.ulVal))
        return E_NOTIMPL;
    }
  }
  return S_OK;
}

STDMETHODIMP_(void) CCrcHasher::Init() throw()
{
  _crc = CRC_INIT_VAL;
}

STDMETHODIMP_(void) CCrcHasher::Update(const void *data, UInt32 size) throw()
{
  _crc = _updateFunc(_crc, data, size, g_CrcTable);
}

STDMETHODIMP_(void) CCrcHasher::Final(Byte *digest) throw()
{
  UInt32 val = CRC_GET_DIGEST(_crc);
  SetUi32(digest, val);
}

REGISTER_HASHER(CCrcHasher, 0x1, "CRC32", 4)
