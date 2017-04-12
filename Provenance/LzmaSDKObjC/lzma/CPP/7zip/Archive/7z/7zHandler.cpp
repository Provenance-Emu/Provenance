// 7zHandler.cpp

#include "StdAfx.h"

#include "../../../../C/CpuArch.h"

#include "../../../Common/ComTry.h"
#include "../../../Common/IntToString.h"

#ifndef __7Z_SET_PROPERTIES
#if !defined(__APPLE__)
#include "../../../Windows/System.h"
#endif
#endif

#include "../Common/ItemNameUtils.h"

#include "7zHandler.h"
#include "7zProperties.h"

#ifdef __7Z_SET_PROPERTIES
#ifdef EXTRACT_ONLY
#include "../Common/ParseProperties.h"
#endif
#endif

using namespace NWindows;
using namespace NCOM;

namespace NArchive {
namespace N7z {

CHandler::CHandler()
{
  #ifndef _NO_CRYPTO
  _isEncrypted = false;
  _passwordIsDefined = false;
  #endif

  #ifdef EXTRACT_ONLY
  
  _crcSize = 4;
  
  #ifdef __7Z_SET_PROPERTIES
  _numThreads = NSystem::GetNumberOfProcessors();
  _useMultiThreadMixer = true;
  #endif
  
  #endif
}

STDMETHODIMP CHandler::GetNumberOfItems(UInt32 *numItems)
{
  *numItems = _db.Files.Size();
  return S_OK;
}

#ifdef _SFX

IMP_IInArchive_ArcProps_NO_Table

STDMETHODIMP CHandler::GetNumberOfProperties(UInt32 *numProps)
{
  *numProps = 0;
  return S_OK;
}

STDMETHODIMP CHandler::GetPropertyInfo(UInt32 /* index */,
      BSTR * /* name */, PROPID * /* propID */, VARTYPE * /* varType */)
{
  return E_NOTIMPL;
}

#else

static const Byte kArcProps[] =
{
  kpidHeadersSize,
  kpidMethod,
  kpidSolid,
  kpidNumBlocks
  // , kpidIsTree
};

IMP_IInArchive_ArcProps

static inline char GetHex(unsigned value)
{
  return (char)((value < 10) ? ('0' + value) : ('A' + (value - 10)));
}

static unsigned ConvertMethodIdToString_Back(char *s, UInt64 id)
{
  int len = 0;
  do
  {
    s[--len] = GetHex((unsigned)id & 0xF); id >>= 4;
    s[--len] = GetHex((unsigned)id & 0xF); id >>= 4;
  }
  while (id != 0);
  return (unsigned)-len;
}

static void ConvertMethodIdToString(AString &res, UInt64 id)
{
  const unsigned kLen = 32;
  char s[kLen];
  unsigned len = kLen - 1;
  s[len] = 0;
  res += s + len - ConvertMethodIdToString_Back(s + len, id);
}

static unsigned GetStringForSizeValue(char *s, UInt32 val)
{
  unsigned i;
  for (i = 0; i <= 31; i++)
    if (((UInt32)1 << i) == val)
    {
      if (i < 10)
      {
        s[0] = (char)('0' + i);
        s[1] = 0;
        return 1;
      }
           if (i < 20) { s[0] = '1'; s[1] = (char)('0' + i - 10); }
      else if (i < 30) { s[0] = '2'; s[1] = (char)('0' + i - 20); }
      else             { s[0] = '3'; s[1] = (char)('0' + i - 30); }
      s[2] = 0;
      return 2;
    }
  char c = 'b';
  if      ((val & ((1 << 20) - 1)) == 0) { val >>= 20; c = 'm'; }
  else if ((val & ((1 << 10) - 1)) == 0) { val >>= 10; c = 'k'; }
  ::ConvertUInt32ToString(val, s);
  unsigned pos = MyStringLen(s);
  s[pos++] = c;
  s[pos] = 0;
  return pos;
}

/*
static inline void AddHexToString(UString &res, Byte value)
{
  res += GetHex((Byte)(value >> 4));
  res += GetHex((Byte)(value & 0xF));
}
*/

static char *AddProp32(char *s, const char *name, UInt32 v)
{
  *s++ = ':';
  s = MyStpCpy(s, name);
  ::ConvertUInt32ToString(v, s);
  return s + MyStringLen(s);
}
 
void CHandler::AddMethodName(AString &s, UInt64 id)
{
  AString name;
  FindMethod(EXTERNAL_CODECS_VARS id, name);
  if (name.IsEmpty())
    ConvertMethodIdToString(s, id);
  else
    s += name;
}

#endif

STDMETHODIMP CHandler::GetArchiveProperty(PROPID propID, PROPVARIANT *value)
{
  #ifndef _SFX
  COM_TRY_BEGIN
  #endif
  NCOM::CPropVariant prop;
  switch (propID)
  {
    #ifndef _SFX
    case kpidMethod:
    {
      AString s;
      const CParsedMethods &pm = _db.ParsedMethods;
      FOR_VECTOR (i, pm.IDs)
      {
        UInt64 id = pm.IDs[i];
        s.Add_Space_if_NotEmpty();
        char temp[16];
        if (id == k_LZMA2)
        {
          s += "LZMA2:";
          if ((pm.Lzma2Prop & 1) == 0)
            ConvertUInt32ToString((pm.Lzma2Prop >> 1) + 12, temp);
          else
            GetStringForSizeValue(temp, 3 << ((pm.Lzma2Prop >> 1) + 11));
          s += temp;
        }
        else if (id == k_LZMA)
        {
          s += "LZMA:";
          GetStringForSizeValue(temp, pm.LzmaDic);
          s += temp;
        }
        else
          AddMethodName(s, id);
      }
      prop = s;
      break;
    }
    case kpidSolid: prop = _db.IsSolid(); break;
    case kpidNumBlocks: prop = (UInt32)_db.NumFolders; break;
    case kpidHeadersSize:  prop = _db.HeadersSize; break;
    case kpidPhySize:  prop = _db.PhySize; break;
    case kpidOffset: if (_db.ArcInfo.StartPosition != 0) prop = _db.ArcInfo.StartPosition; break;
    /*
    case kpidIsTree: if (_db.IsTree) prop = true; break;
    case kpidIsAltStream: if (_db.ThereAreAltStreams) prop = true; break;
    case kpidIsAux: if (_db.IsTree) prop = true; break;
    */
    // case kpidError: if (_db.ThereIsHeaderError) prop = "Header error"; break;
    #endif
    
    case kpidWarningFlags:
    {
      UInt32 v = 0;
      if (_db.StartHeaderWasRecovered) v |= kpv_ErrorFlags_HeadersError;
      if (_db.UnsupportedFeatureWarning) v |= kpv_ErrorFlags_UnsupportedFeature;
      if (v != 0)
        prop = v;
      break;
    }
    
    case kpidErrorFlags:
    {
      UInt32 v = 0;
      if (!_db.IsArc) v |= kpv_ErrorFlags_IsNotArc;
      if (_db.ThereIsHeaderError) v |= kpv_ErrorFlags_HeadersError;
      if (_db.UnexpectedEnd) v |= kpv_ErrorFlags_UnexpectedEnd;
      // if (_db.UnsupportedVersion) v |= kpv_ErrorFlags_Unsupported;
      if (_db.UnsupportedFeatureError) v |= kpv_ErrorFlags_UnsupportedFeature;
      prop = v;
      break;
    }
  }
  prop.Detach(value);
  return S_OK;
  #ifndef _SFX
  COM_TRY_END
  #endif
}

static void SetFileTimeProp_From_UInt64Def(PROPVARIANT *prop, const CUInt64DefVector &v, int index)
{
  UInt64 value;
  if (v.GetItem(index, value))
    PropVarEm_Set_FileTime64(prop, value);
}

bool CHandler::IsFolderEncrypted(CNum folderIndex) const
{
  if (folderIndex == kNumNoIndex)
    return false;
  size_t startPos = _db.FoCodersDataOffset[folderIndex];
  const Byte *p = _db.CodersData + startPos;
  size_t size = _db.FoCodersDataOffset[folderIndex + 1] - startPos;
  CInByte2 inByte;
  inByte.Init(p, size);
  
  CNum numCoders = inByte.ReadNum();
  for (; numCoders != 0; numCoders--)
  {
    Byte mainByte = inByte.ReadByte();
    unsigned idSize = (mainByte & 0xF);
    const Byte *longID = inByte.GetPtr();
    UInt64 id64 = 0;
    for (unsigned j = 0; j < idSize; j++)
      id64 = ((id64 << 8) | longID[j]);
    inByte.SkipDataNoCheck(idSize);
    if (id64 == k_AES)
      return true;
    if ((mainByte & 0x20) != 0)
      inByte.SkipDataNoCheck(inByte.ReadNum());
  }
  return false;
}

STDMETHODIMP CHandler::GetNumRawProps(UInt32 *numProps)
{
  *numProps = 0;
  return S_OK;
}

STDMETHODIMP CHandler::GetRawPropInfo(UInt32 /* index */, BSTR *name, PROPID *propID)
{
  *name = NULL;
  *propID = kpidNtSecure;
  return S_OK;
}

STDMETHODIMP CHandler::GetParent(UInt32 /* index */, UInt32 *parent, UInt32 *parentType)
{
  /*
  const CFileItem &file = _db.Files[index];
  *parentType = (file.IsAltStream ? NParentType::kAltStream : NParentType::kDir);
  *parent = (UInt32)(Int32)file.Parent;
  */
  *parentType = NParentType::kDir;
  *parent = (UInt32)(Int32)-1;
  return S_OK;
}

STDMETHODIMP CHandler::GetRawProp(UInt32 index, PROPID propID, const void **data, UInt32 *dataSize, UInt32 *propType)
{
  *data = NULL;
  *dataSize = 0;
  *propType = 0;

  if (/* _db.IsTree && propID == kpidName ||
      !_db.IsTree && */ propID == kpidPath)
  {
    if (_db.NameOffsets && _db.NamesBuf)
    {
      size_t offset = _db.NameOffsets[index];
      size_t size = (_db.NameOffsets[index + 1] - offset) * 2;
      if (size < ((UInt32)1 << 31))
      {
        *data = (const void *)(_db.NamesBuf + offset * 2);
        *dataSize = (UInt32)size;
        *propType = NPropDataType::kUtf16z;
      }
    }
    return S_OK;
  }
  /*
  if (propID == kpidNtSecure)
  {
    if (index < (UInt32)_db.SecureIDs.Size())
    {
      int id = _db.SecureIDs[index];
      size_t offs = _db.SecureOffsets[id];
      size_t size = _db.SecureOffsets[id + 1] - offs;
      if (size >= 0)
      {
        *data = _db.SecureBuf + offs;
        *dataSize = (UInt32)size;
        *propType = NPropDataType::kRaw;
      }
    }
  }
  */
  return S_OK;
}

#ifndef _SFX

HRESULT CHandler::SetMethodToProp(CNum folderIndex, PROPVARIANT *prop) const
{
  PropVariant_Clear(prop);
  if (folderIndex == kNumNoIndex)
    return S_OK;
  // for (int ttt = 0; ttt < 1; ttt++) {
  const unsigned kTempSize = 256;
  char temp[kTempSize];
  unsigned pos = kTempSize;
  temp[--pos] = 0;
 
  size_t startPos = _db.FoCodersDataOffset[folderIndex];
  const Byte *p = _db.CodersData + startPos;
  size_t size = _db.FoCodersDataOffset[folderIndex + 1] - startPos;
  CInByte2 inByte;
  inByte.Init(p, size);
  
  // numCoders == 0 ???
  CNum numCoders = inByte.ReadNum();
  bool needSpace = false;
  
  for (; numCoders != 0; numCoders--, needSpace = true)
  {
    if (pos < 32) // max size of property
      break;
    Byte mainByte = inByte.ReadByte();
    unsigned idSize = (mainByte & 0xF);
    const Byte *longID = inByte.GetPtr();
    UInt64 id64 = 0;
    for (unsigned j = 0; j < idSize; j++)
      id64 = ((id64 << 8) | longID[j]);
    inByte.SkipDataNoCheck(idSize);

    if ((mainByte & 0x10) != 0)
    {
      inByte.ReadNum(); // NumInStreams
      inByte.ReadNum(); // NumOutStreams
    }
  
    CNum propsSize = 0;
    const Byte *props = NULL;
    if ((mainByte & 0x20) != 0)
    {
      propsSize = inByte.ReadNum();
      props = inByte.GetPtr();
      inByte.SkipDataNoCheck(propsSize);
    }
    
    const char *name = NULL;
    char s[32];
    s[0] = 0;
    
    if (id64 <= (UInt32)0xFFFFFFFF)
    {
      UInt32 id = (UInt32)id64;
      if (id == k_LZMA)
      {
        name = "LZMA";
        if (propsSize == 5)
        {
          UInt32 dicSize = GetUi32((const Byte *)props + 1);
          char *dest = s + GetStringForSizeValue(s, dicSize);
          UInt32 d = props[0];
          if (d != 0x5D)
          {
            UInt32 lc = d % 9;
            d /= 9;
            UInt32 pb = d / 5;
            UInt32 lp = d % 5;
            if (lc != 3) dest = AddProp32(dest, "lc", lc);
            if (lp != 0) dest = AddProp32(dest, "lp", lp);
            if (pb != 2) dest = AddProp32(dest, "pb", pb);
          }
        }
      }
      else if (id == k_LZMA2)
      {
        name = "LZMA2";
        if (propsSize == 1)
        {
          Byte d = props[0];
          if ((d & 1) == 0)
            ConvertUInt32ToString((UInt32)((d >> 1) + 12), s);
          else
            GetStringForSizeValue(s, 3 << ((d >> 1) + 11));
        }
      }
      else if (id == k_PPMD)
      {
        name = "PPMD";
        if (propsSize == 5)
        {
          Byte order = *props;
          char *dest = s;
          *dest++ = 'o';
          ConvertUInt32ToString(order, dest);
          dest += MyStringLen(dest);
          dest = MyStpCpy(dest, ":mem");
          GetStringForSizeValue(dest, GetUi32(props + 1));
        }
      }
      else if (id == k_Delta)
      {
        name = "Delta";
        if (propsSize == 1)
          ConvertUInt32ToString((UInt32)props[0] + 1, s);
      }
      else if (id == k_BCJ2) name = "BCJ2";
      else if (id == k_BCJ) name = "BCJ";
      else if (id == k_AES)
      {
        name = "7zAES";
        if (propsSize >= 1)
        {
          Byte firstByte = props[0];
          UInt32 numCyclesPower = firstByte & 0x3F;
          ConvertUInt32ToString(numCyclesPower, s);
        }
      }
    }
    
    if (name)
    {
      unsigned nameLen = MyStringLen(name);
      unsigned propsLen = MyStringLen(s);
      unsigned totalLen = nameLen + propsLen;
      if (propsLen != 0)
        totalLen++;
      if (needSpace)
        totalLen++;
      if (totalLen + 5 >= pos)
        break;
      pos -= totalLen;
      MyStringCopy(temp + pos, name);
      if (propsLen != 0)
      {
        char *dest = temp + pos + nameLen;
        *dest++ = ':';
        MyStringCopy(dest, s);
      }
      if (needSpace)
        temp[pos + totalLen - 1] = ' ';
    }
    else
    {
      AString methodName;
      FindMethod(EXTERNAL_CODECS_VARS id64, methodName);
      if (needSpace)
        temp[--pos] = ' ';
      if (methodName.IsEmpty())
        pos -= ConvertMethodIdToString_Back(temp + pos, id64);
      else
      {
        unsigned len = methodName.Len();
        if (len + 5 > pos)
          break;
        pos -= len;
        for (unsigned i = 0; i < len; i++)
          temp[pos + i] = methodName[i];
      }
    }
  }
  
  if (numCoders != 0 && pos >= 4)
  {
    temp[--pos] = ' ';
    temp[--pos] = '.';
    temp[--pos] = '.';
    temp[--pos] = '.';
  }
  
  return PropVarEm_Set_Str(prop, temp + pos);
  // }
}

#endif

STDMETHODIMP CHandler::GetProperty(UInt32 index, PROPID propID, PROPVARIANT *value)
{
  PropVariant_Clear(value);
  // COM_TRY_BEGIN
  // NCOM::CPropVariant prop;
  
  /*
  const CRef2 &ref2 = _refs[index];
  if (ref2.Refs.IsEmpty())
    return E_FAIL;
  const CRef &ref = ref2.Refs.Front();
  */
  
  const CFileItem &item = _db.Files[index];
  UInt32 index2 = index;

  switch (propID)
  {
    case kpidIsDir: PropVarEm_Set_Bool(value, item.IsDir); break;
    case kpidSize:
    {
      PropVarEm_Set_UInt64(value, item.Size);
      // prop = ref2.Size;
      break;
    }
    case kpidPackSize:
    {
      // prop = ref2.PackSize;
      {
        CNum folderIndex = _db.FileIndexToFolderIndexMap[index2];
        if (folderIndex != kNumNoIndex)
        {
          if (_db.FolderStartFileIndex[folderIndex] == (CNum)index2)
            PropVarEm_Set_UInt64(value, _db.GetFolderFullPackSize(folderIndex));
          /*
          else
            PropVarEm_Set_UInt64(value, 0);
          */
        }
        else
          PropVarEm_Set_UInt64(value, 0);
      }
      break;
    }
    // case kpidIsAux: prop = _db.IsItemAux(index2); break;
    case kpidPosition:  { UInt64 v; if (_db.StartPos.GetItem(index2, v)) PropVarEm_Set_UInt64(value, v); break; }
    case kpidCTime:  SetFileTimeProp_From_UInt64Def(value, _db.CTime, index2); break;
    case kpidATime:  SetFileTimeProp_From_UInt64Def(value, _db.ATime, index2); break;
    case kpidMTime:  SetFileTimeProp_From_UInt64Def(value, _db.MTime, index2); break;
    case kpidAttrib:  if (item.AttribDefined) PropVarEm_Set_UInt32(value, item.Attrib); break;
    case kpidCRC:  if (item.CrcDefined) PropVarEm_Set_UInt32(value, item.Crc); break;
    case kpidEncrypted:  PropVarEm_Set_Bool(value, IsFolderEncrypted(_db.FileIndexToFolderIndexMap[index2])); break;
    case kpidIsAnti:  PropVarEm_Set_Bool(value, _db.IsItemAnti(index2)); break;
    /*
    case kpidIsAltStream:  prop = item.IsAltStream; break;
    case kpidNtSecure:
      {
        int id = _db.SecureIDs[index];
        size_t offs = _db.SecureOffsets[id];
        size_t size = _db.SecureOffsets[id + 1] - offs;
        if (size >= 0)
        {
          prop.SetBlob(_db.SecureBuf + offs, (ULONG)size);
        }
        break;
      }
    */

    case kpidPath: return _db.GetPath_Prop(index, value);
    
    #ifndef _SFX
    
    case kpidMethod: return SetMethodToProp(_db.FileIndexToFolderIndexMap[index2], value);
    case kpidBlock:
      {
        CNum folderIndex = _db.FileIndexToFolderIndexMap[index2];
        if (folderIndex != kNumNoIndex)
          PropVarEm_Set_UInt32(value, (UInt32)folderIndex);
      }
      break;
    /*
    case kpidPackedSize0:
    case kpidPackedSize1:
    case kpidPackedSize2:
    case kpidPackedSize3:
    case kpidPackedSize4:
      {
        CNum folderIndex = _db.FileIndexToFolderIndexMap[index2];
        if (folderIndex != kNumNoIndex)
        {
          if (_db.FolderStartFileIndex[folderIndex] == (CNum)index2 &&
              _db.FoStartPackStreamIndex[folderIndex + 1] -
              _db.FoStartPackStreamIndex[folderIndex] > (propID - kpidPackedSize0))
          {
            PropVarEm_Set_UInt64(value, _db.GetFolderPackStreamSize(folderIndex, propID - kpidPackedSize0));
          }
        }
        else
          PropVarEm_Set_UInt64(value, 0);
      }
      break;
    */
    
    #endif
  }
  // prop.Detach(value);
  return S_OK;
  // COM_TRY_END
}

STDMETHODIMP CHandler::Open(IInStream *stream,
    const UInt64 *maxCheckStartPosition,
    IArchiveOpenCallback *openArchiveCallback)
{
  COM_TRY_BEGIN
  Close();
  #ifndef _SFX
  _fileInfoPopIDs.Clear();
  #endif
  
  try
  {
    CMyComPtr<IArchiveOpenCallback> openArchiveCallbackTemp = openArchiveCallback;

    #ifndef _NO_CRYPTO
    CMyComPtr<ICryptoGetTextPassword> getTextPassword;
    if (openArchiveCallback)
      openArchiveCallbackTemp.QueryInterface(IID_ICryptoGetTextPassword, &getTextPassword);
    #endif

    CInArchive archive(
          #ifdef __7Z_SET_PROPERTIES
          _useMultiThreadMixer
          #else
          true
          #endif
          );
    _db.IsArc = false;
    RINOK(archive.Open(stream, maxCheckStartPosition));
    _db.IsArc = true;
    
    HRESULT result = archive.ReadDatabase(
        EXTERNAL_CODECS_VARS
        _db
        #ifndef _NO_CRYPTO
          , getTextPassword, _isEncrypted, _passwordIsDefined, _password
        #endif
        );
    RINOK(result);
    
    _inStream = stream;
  }
  catch(...)
  {
    Close();
    // return E_INVALIDARG;
    // return S_FALSE;
    // we must return out_of_memory here
    return E_OUTOFMEMORY;
  }
  // _inStream = stream;
  #ifndef _SFX
  FillPopIDs();
  #endif
  return S_OK;
  COM_TRY_END
}

STDMETHODIMP CHandler::Close()
{
  COM_TRY_BEGIN
  _inStream.Release();
  _db.Clear();
  #ifndef _NO_CRYPTO
  _isEncrypted = false;
  _passwordIsDefined = false;
  _password.Empty();
  #endif
  return S_OK;
  COM_TRY_END
}

#ifdef __7Z_SET_PROPERTIES
#ifdef EXTRACT_ONLY

STDMETHODIMP CHandler::SetProperties(const wchar_t * const *names, const PROPVARIANT *values, UInt32 numProps)
{
  COM_TRY_BEGIN
  const UInt32 numProcessors = NSystem::GetNumberOfProcessors();
  _numThreads = numProcessors;
  _useMultiThreadMixer = true;

  for (UInt32 i = 0; i < numProps; i++)
  {
    UString name = names[i];
    name.MakeLower_Ascii();
    if (name.IsEmpty())
      return E_INVALIDARG;
    const PROPVARIANT &value = values[i];
    UInt32 number;
    unsigned index = ParseStringToUInt32(name, number);
    if (index == 0)
    {
      if (name.IsEqualTo("mtf"))
      {
        RINOK(PROPVARIANT_to_bool(value, _useMultiThreadMixer));
        continue;
      }
      if (name.IsPrefixedBy_Ascii_NoCase("mt"))
      {
        RINOK(ParseMtProp(name.Ptr(2), value, numProcessors, _numThreads));
        continue;
      }
      else
        return E_INVALIDARG;
    }
  }
  return S_OK;
  COM_TRY_END
}

#endif
#endif

IMPL_ISetCompressCodecsInfo

}}
