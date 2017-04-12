// 7zHandlerOut.cpp

#include "StdAfx.h"

#include "../../../Common/ComTry.h"
#include "../../../Common/StringToInt.h"
#include "../../../Common/Wildcard.h"

#include "../Common/ItemNameUtils.h"
#include "../Common/ParseProperties.h"

#include "7zHandler.h"
#include "7zOut.h"
#include "7zUpdate.h"

using namespace NWindows;

namespace NArchive {
namespace N7z {

static const char *k_LZMA_Name = "LZMA";
static const char *kDefaultMethodName = "LZMA2";
static const char *k_Copy_Name = "Copy";

static const char *k_MatchFinder_ForHeaders = "BT2";
#if defined(LZMASDKOBJC_OMIT_UNUSED_CODE)
#define k_NumFastBytes_ForHeaders 273
#define k_Level_ForHeaders 5
#else
static const UInt32 k_NumFastBytes_ForHeaders = 273;
static const UInt32 k_Level_ForHeaders = 5;
#endif
static const UInt32 k_Dictionary_ForHeaders =
#ifdef UNDER_CE
  1 << 18;
#else
  1 << 20;
#endif

STDMETHODIMP CHandler::GetFileTimeType(UInt32 *type)
{
  *type = NFileTimeType::kWindows;
  return S_OK;
}

HRESULT CHandler::PropsMethod_To_FullMethod(CMethodFull &dest, const COneMethodInfo &m)
{
  if (!FindMethod(
      EXTERNAL_CODECS_VARS
      m.MethodName, dest.Id, dest.NumStreams))
    return E_INVALIDARG;
  (CProps &)dest = (CProps &)m;
  return S_OK;
}

HRESULT CHandler::SetHeaderMethod(CCompressionMethodMode &headerMethod)
{
  if (!_compressHeaders)
    return S_OK;
  COneMethodInfo m;
  m.MethodName = k_LZMA_Name;
  m.AddProp_Ascii(NCoderPropID::kMatchFinder, k_MatchFinder_ForHeaders);
  m.AddProp_Level(k_Level_ForHeaders);
  m.AddProp32(NCoderPropID::kNumFastBytes, k_NumFastBytes_ForHeaders);
  m.AddProp32(NCoderPropID::kDictionarySize, k_Dictionary_ForHeaders);
  m.AddProp_NumThreads(1);

  CMethodFull &methodFull = headerMethod.Methods.AddNew();
  return PropsMethod_To_FullMethod(methodFull, m);
}

HRESULT CHandler::SetMainMethod(
    CCompressionMethodMode &methodMode
    #ifndef _7ZIP_ST
    , UInt32 numThreads
    #endif
    )
{
  methodMode.Bonds = _bonds;

  CObjectVector<COneMethodInfo> methods = _methods;

  {
    FOR_VECTOR (i, methods)
    {
      AString &methodName = methods[i].MethodName;
      if (methodName.IsEmpty())
        methodName = kDefaultMethodName;
    }
    if (methods.IsEmpty())
    {
      COneMethodInfo &m = methods.AddNew();
      m.MethodName = (GetLevel() == 0 ? k_Copy_Name : kDefaultMethodName);
      methodMode.DefaultMethod_was_Inserted = true;
    }
  }

  if (!_filterMethod.MethodName.IsEmpty())
  {
    // if (methodMode.Bonds.IsEmpty())
    {
      FOR_VECTOR (k, methodMode.Bonds)
      {
        CBond2 &bond = methodMode.Bonds[k];
        bond.InCoder++;
        bond.OutCoder++;
      }
      methods.Insert(0, _filterMethod);
      methodMode.Filter_was_Inserted = true;
    }
  }

  const UInt64 kSolidBytes_Min = (1 << 24);
  const UInt64 kSolidBytes_Max = ((UInt64)1 << 32) - 1;

  bool needSolid = false;
  
  FOR_VECTOR (i, methods)
  {
    COneMethodInfo &oneMethodInfo = methods[i];
    SetGlobalLevelAndThreads(oneMethodInfo
      #ifndef _7ZIP_ST
      , numThreads
      #endif
      );

    CMethodFull &methodFull = methodMode.Methods.AddNew();
    RINOK(PropsMethod_To_FullMethod(methodFull, oneMethodInfo));

    if (methodFull.Id != k_Copy)
      needSolid = true;

    if (_numSolidBytesDefined)
      continue;

    UInt32 dicSize;
    switch (methodFull.Id)
    {
      case k_LZMA:
      case k_LZMA2: dicSize = oneMethodInfo.Get_Lzma_DicSize(); break;
      case k_PPMD: dicSize = oneMethodInfo.Get_Ppmd_MemSize(); break;
      case k_Deflate: dicSize = (UInt32)1 << 15; break;
      case k_BZip2: dicSize = oneMethodInfo.Get_BZip2_BlockSize(); break;
      default: continue;
    }
    
    _numSolidBytes = (UInt64)dicSize << 7;
    if (_numSolidBytes < kSolidBytes_Min) _numSolidBytes = kSolidBytes_Min;
    if (_numSolidBytes > kSolidBytes_Max) _numSolidBytes = kSolidBytes_Max;
    _numSolidBytesDefined = true;
  }

  if (!_numSolidBytesDefined)
    if (needSolid)
      _numSolidBytes = kSolidBytes_Max;
    else
      _numSolidBytes = 0;
  _numSolidBytesDefined = true;
  return S_OK;
}

static HRESULT GetTime(IArchiveUpdateCallback *updateCallback, int index, PROPID propID, UInt64 &ft, bool &ftDefined)
{
  // ft = 0;
  // ftDefined = false;
  NCOM::CPropVariant prop;
  RINOK(updateCallback->GetProperty(index, propID, &prop));
  if (prop.vt == VT_FILETIME)
  {
    ft = prop.filetime.dwLowDateTime | ((UInt64)prop.filetime.dwHighDateTime << 32);
    ftDefined = true;
  }
  else if (prop.vt != VT_EMPTY)
    return E_INVALIDARG;
  else
  {
    ft = 0;
    ftDefined = false;
  }
  return S_OK;
}

/*

#ifdef _WIN32
static const wchar_t kDirDelimiter1 = L'\\';
#endif
static const wchar_t kDirDelimiter2 = L'/';

static inline bool IsCharDirLimiter(wchar_t c)
{
  return (
    #ifdef _WIN32
    c == kDirDelimiter1 ||
    #endif
    c == kDirDelimiter2);
}

static int FillSortIndex(CObjectVector<CTreeFolder> &treeFolders, int cur, int curSortIndex)
{
  CTreeFolder &tf = treeFolders[cur];
  tf.SortIndex = curSortIndex++;
  for (int i = 0; i < tf.SubFolders.Size(); i++)
    curSortIndex = FillSortIndex(treeFolders, tf.SubFolders[i], curSortIndex);
  tf.SortIndexEnd = curSortIndex;
  return curSortIndex;
}

static int FindSubFolder(const CObjectVector<CTreeFolder> &treeFolders, int cur, const UString &name, int &insertPos)
{
  const CIntVector &subFolders = treeFolders[cur].SubFolders;
  int left = 0, right = subFolders.Size();
  insertPos = -1;
  for (;;)
  {
    if (left == right)
    {
      insertPos = left;
      return -1;
    }
    int mid = (left + right) / 2;
    int midFolder = subFolders[mid];
    int compare = CompareFileNames(name, treeFolders[midFolder].Name);
    if (compare == 0)
      return midFolder;
    if (compare < 0)
      right = mid;
    else
      left = mid + 1;
  }
}

static int AddFolder(CObjectVector<CTreeFolder> &treeFolders, int cur, const UString &name)
{
  int insertPos;
  int folderIndex = FindSubFolder(treeFolders, cur, name, insertPos);
  if (folderIndex < 0)
  {
    folderIndex = treeFolders.Size();
    CTreeFolder &newFolder = treeFolders.AddNew();
    newFolder.Parent = cur;
    newFolder.Name = name;
    treeFolders[cur].SubFolders.Insert(insertPos, folderIndex);
  }
  // else if (treeFolders[folderIndex].IsAltStreamFolder != isAltStreamFolder) throw 1123234234;
  return folderIndex;
}
*/

STDMETHODIMP CHandler::UpdateItems(ISequentialOutStream *outStream, UInt32 numItems,
    IArchiveUpdateCallback *updateCallback)
{
  COM_TRY_BEGIN

  const CDbEx *db = 0;
  #ifdef _7Z_VOL
  if (_volumes.Size() > 1)
    return E_FAIL;
  const CVolume *volume = 0;
  if (_volumes.Size() == 1)
  {
    volume = &_volumes.Front();
    db = &volume->Database;
  }
  #else
  if (_inStream != 0)
    db = &_db;
  #endif

  /*
  CMyComPtr<IArchiveGetRawProps> getRawProps;
  updateCallback->QueryInterface(IID_IArchiveGetRawProps, (void **)&getRawProps);

  CUniqBlocks secureBlocks;
  secureBlocks.AddUniq(NULL, 0);

  CObjectVector<CTreeFolder> treeFolders;
  {
    CTreeFolder folder;
    folder.Parent = -1;
    treeFolders.Add(folder);
  }
  */

  CObjectVector<CUpdateItem> updateItems;

  bool need_CTime = (Write_CTime.Def && Write_CTime.Val);
  bool need_ATime = (Write_ATime.Def && Write_ATime.Val);
  bool need_MTime = (Write_MTime.Def && Write_MTime.Val || !Write_MTime.Def);
  
  if (db && !db->Files.IsEmpty())
  {
    if (!Write_CTime.Def) need_CTime = !db->CTime.Defs.IsEmpty();
    if (!Write_ATime.Def) need_ATime = !db->ATime.Defs.IsEmpty();
    if (!Write_MTime.Def) need_MTime = !db->MTime.Defs.IsEmpty();
  }

  UString s;

  for (UInt32 i = 0; i < numItems; i++)
  {
    Int32 newData, newProps;
    UInt32 indexInArchive;
    if (!updateCallback)
      return E_FAIL;
    RINOK(updateCallback->GetUpdateItemInfo(i, &newData, &newProps, &indexInArchive));
    CUpdateItem ui;
    ui.NewProps = IntToBool(newProps);
    ui.NewData = IntToBool(newData);
    ui.IndexInArchive = indexInArchive;
    ui.IndexInClient = i;
    ui.IsAnti = false;
    ui.Size = 0;

    UString name;
    // bool isAltStream = false;
    if (ui.IndexInArchive != -1)
    {
      if (db == 0 || (unsigned)ui.IndexInArchive >= db->Files.Size())
        return E_INVALIDARG;
      const CFileItem &fi = db->Files[ui.IndexInArchive];
      if (!ui.NewProps)
      {
        _db.GetPath(ui.IndexInArchive, name);
      }
      ui.IsDir = fi.IsDir;
      ui.Size = fi.Size;
      // isAltStream = fi.IsAltStream;
      ui.IsAnti = db->IsItemAnti(ui.IndexInArchive);
      
      if (!ui.NewProps)
      {
        ui.CTimeDefined = db->CTime.GetItem(ui.IndexInArchive, ui.CTime);
        ui.ATimeDefined = db->ATime.GetItem(ui.IndexInArchive, ui.ATime);
        ui.MTimeDefined = db->MTime.GetItem(ui.IndexInArchive, ui.MTime);
      }
    }

    if (ui.NewProps)
    {
      bool folderStatusIsDefined;
      {
        NCOM::CPropVariant prop;
        RINOK(updateCallback->GetProperty(i, kpidAttrib, &prop));
        if (prop.vt == VT_EMPTY)
          ui.AttribDefined = false;
        else if (prop.vt != VT_UI4)
          return E_INVALIDARG;
        else
        {
          ui.Attrib = prop.ulVal;
          ui.AttribDefined = true;
        }
      }
      
      // we need MTime to sort files.
      if (need_CTime) RINOK(GetTime(updateCallback, i, kpidCTime, ui.CTime, ui.CTimeDefined));
      if (need_ATime) RINOK(GetTime(updateCallback, i, kpidATime, ui.ATime, ui.ATimeDefined));
      if (need_MTime) RINOK(GetTime(updateCallback, i, kpidMTime, ui.MTime, ui.MTimeDefined));

      /*
      if (getRawProps)
      {
        const void *data;
        UInt32 dataSize;
        UInt32 propType;

        getRawProps->GetRawProp(i, kpidNtSecure, &data, &dataSize, &propType);
        if (dataSize != 0 && propType != NPropDataType::kRaw)
          return E_FAIL;
        ui.SecureIndex = secureBlocks.AddUniq((const Byte *)data, dataSize);
      }
      */

      {
        NCOM::CPropVariant prop;
        RINOK(updateCallback->GetProperty(i, kpidPath, &prop));
        if (prop.vt == VT_EMPTY)
        {
        }
        else if (prop.vt != VT_BSTR)
          return E_INVALIDARG;
        else
        {
          name = NItemName::MakeLegalName(prop.bstrVal);
        }
      }
      {
        NCOM::CPropVariant prop;
        RINOK(updateCallback->GetProperty(i, kpidIsDir, &prop));
        if (prop.vt == VT_EMPTY)
          folderStatusIsDefined = false;
        else if (prop.vt != VT_BOOL)
          return E_INVALIDARG;
        else
        {
          ui.IsDir = (prop.boolVal != VARIANT_FALSE);
          folderStatusIsDefined = true;
        }
      }

      {
        NCOM::CPropVariant prop;
        RINOK(updateCallback->GetProperty(i, kpidIsAnti, &prop));
        if (prop.vt == VT_EMPTY)
          ui.IsAnti = false;
        else if (prop.vt != VT_BOOL)
          return E_INVALIDARG;
        else
          ui.IsAnti = (prop.boolVal != VARIANT_FALSE);
      }

      /*
      {
        NCOM::CPropVariant prop;
        RINOK(updateCallback->GetProperty(i, kpidIsAltStream, &prop));
        if (prop.vt == VT_EMPTY)
          isAltStream = false;
        else if (prop.vt != VT_BOOL)
          return E_INVALIDARG;
        else
          isAltStream = (prop.boolVal != VARIANT_FALSE);
      }
      */

      if (ui.IsAnti)
      {
        ui.AttribDefined = false;

        ui.CTimeDefined = false;
        ui.ATimeDefined = false;
        ui.MTimeDefined = false;
        
        ui.Size = 0;
      }

      if (!folderStatusIsDefined && ui.AttribDefined)
        ui.SetDirStatusFromAttrib();
    }
    else
    {
      /*
      if (_db.SecureIDs.IsEmpty())
        ui.SecureIndex = secureBlocks.AddUniq(NULL, 0);
      else
      {
        int id = _db.SecureIDs[ui.IndexInArchive];
        size_t offs = _db.SecureOffsets[id];
        size_t size = _db.SecureOffsets[id + 1] - offs;
        ui.SecureIndex = secureBlocks.AddUniq(_db.SecureBuf + offs, size);
      }
      */
    }

    /*
    {
      int folderIndex = 0;
      if (_useParents)
      {
        int j;
        s.Empty();
        for (j = 0; j < name.Len(); j++)
        {
          wchar_t c = name[j];
          if (IsCharDirLimiter(c))
          {
            folderIndex = AddFolder(treeFolders, folderIndex, s);
            s.Empty();
            continue;
          }
          s += c;
        }
        if (isAltStream)
        {
          int colonPos = s.Find(':');
          if (colonPos < 0)
          {
            // isAltStream = false;
            return E_INVALIDARG;
          }
          UString mainName = s.Left(colonPos);
          int newFolderIndex = AddFolder(treeFolders, folderIndex, mainName);
          if (treeFolders[newFolderIndex].UpdateItemIndex < 0)
          {
            for (int j = updateItems.Size() - 1; j >= 0; j--)
            {
              CUpdateItem &ui2 = updateItems[j];
              if (ui2.ParentFolderIndex == folderIndex
                  && ui2.Name == mainName)
              {
                ui2.TreeFolderIndex = newFolderIndex;
                treeFolders[newFolderIndex].UpdateItemIndex = j;
              }
            }
          }
          folderIndex = newFolderIndex;
          s.Delete(0, colonPos + 1);
        }
        ui.Name = s;
      }
      else
        ui.Name = name;
      ui.IsAltStream = isAltStream;
      ui.ParentFolderIndex = folderIndex;
      ui.TreeFolderIndex = -1;
      if (ui.IsDir && !s.IsEmpty())
      {
        ui.TreeFolderIndex = AddFolder(treeFolders, folderIndex, s);
        treeFolders[ui.TreeFolderIndex].UpdateItemIndex = updateItems.Size();
      }
    }
    */
    ui.Name = name;

    if (ui.NewData)
    {
      ui.Size = 0;
      if (!ui.IsDir)
      {
        NCOM::CPropVariant prop;
        RINOK(updateCallback->GetProperty(i, kpidSize, &prop));
        if (prop.vt != VT_UI8)
          return E_INVALIDARG;
        ui.Size = (UInt64)prop.uhVal.QuadPart;
        if (ui.Size != 0 && ui.IsAnti)
          return E_INVALIDARG;
      }
    }
    
    updateItems.Add(ui);
  }

  /*
  FillSortIndex(treeFolders, 0, 0);
  for (i = 0; i < (UInt32)updateItems.Size(); i++)
  {
    CUpdateItem &ui = updateItems[i];
    ui.ParentSortIndex = treeFolders[ui.ParentFolderIndex].SortIndex;
    ui.ParentSortIndexEnd = treeFolders[ui.ParentFolderIndex].SortIndexEnd;
  }
  */

  CCompressionMethodMode methodMode, headerMethod;

  HRESULT res = SetMainMethod(methodMode
    #ifndef _7ZIP_ST
    , _numThreads
    #endif
    );
  RINOK(res);

  RINOK(SetHeaderMethod(headerMethod));
  
  #ifndef _7ZIP_ST
  methodMode.NumThreads = _numThreads;
  methodMode.MultiThreadMixer = _useMultiThreadMixer;
  headerMethod.NumThreads = 1;
  headerMethod.MultiThreadMixer = _useMultiThreadMixer;
  #endif

  CMyComPtr<ICryptoGetTextPassword2> getPassword2;
  updateCallback->QueryInterface(IID_ICryptoGetTextPassword2, (void **)&getPassword2);

  methodMode.PasswordIsDefined = false;
  methodMode.Password.Empty();
  if (getPassword2)
  {
    CMyComBSTR password;
    Int32 passwordIsDefined;
    RINOK(getPassword2->CryptoGetTextPassword2(&passwordIsDefined, &password));
    methodMode.PasswordIsDefined = IntToBool(passwordIsDefined);
    if (methodMode.PasswordIsDefined && password)
      methodMode.Password = password;
  }

  bool compressMainHeader = _compressHeaders;  // check it

  bool encryptHeaders = false;

  #ifndef _NO_CRYPTO
  if (!methodMode.PasswordIsDefined && _passwordIsDefined)
  {
    // if header is compressed, we use that password for updated archive
    methodMode.PasswordIsDefined = true;
    methodMode.Password = _password;
  }
  #endif

  if (methodMode.PasswordIsDefined)
  {
    if (_encryptHeadersSpecified)
      encryptHeaders = _encryptHeaders;
    #ifndef _NO_CRYPTO
    else
      encryptHeaders = _passwordIsDefined;
    #endif
    compressMainHeader = true;
    if (encryptHeaders)
    {
      headerMethod.PasswordIsDefined = methodMode.PasswordIsDefined;
      headerMethod.Password = methodMode.Password;
    }
  }

  if (numItems < 2)
    compressMainHeader = false;

  int level = GetLevel();

  CUpdateOptions options;
  options.Method = &methodMode;
  options.HeaderMethod = (_compressHeaders || encryptHeaders) ? &headerMethod : NULL;
  options.UseFilters = (level != 0 && _autoFilter && !methodMode.Filter_was_Inserted);
  options.MaxFilter = (level >= 8);
  options.AnalysisLevel = GetAnalysisLevel();

  options.HeaderOptions.CompressMainHeader = compressMainHeader;
  /*
  options.HeaderOptions.WriteCTime = Write_CTime;
  options.HeaderOptions.WriteATime = Write_ATime;
  options.HeaderOptions.WriteMTime = Write_MTime;
  */
  
  options.NumSolidFiles = _numSolidFiles;
  options.NumSolidBytes = _numSolidBytes;
  options.SolidExtension = _solidExtension;
  options.UseTypeSorting = _useTypeSorting;

  options.RemoveSfxBlock = _removeSfxBlock;
  // options.VolumeMode = _volumeMode;

  options.MultiThreadMixer = _useMultiThreadMixer;

  COutArchive archive;
  CArchiveDatabaseOut newDatabase;

  CMyComPtr<ICryptoGetTextPassword> getPassword;
  updateCallback->QueryInterface(IID_ICryptoGetTextPassword, (void **)&getPassword);
  
  /*
  if (secureBlocks.Sorted.Size() > 1)
  {
    secureBlocks.GetReverseMap();
    for (int i = 0; i < updateItems.Size(); i++)
    {
      int &secureIndex = updateItems[i].SecureIndex;
      secureIndex = secureBlocks.BufIndexToSortedIndex[secureIndex];
    }
  }
  */

  res = Update(
      EXTERNAL_CODECS_VARS
      #ifdef _7Z_VOL
      volume ? volume->Stream: 0,
      volume ? db : 0,
      #else
      _inStream,
      db,
      #endif
      updateItems,
      // treeFolders,
      // secureBlocks,
      archive, newDatabase, outStream, updateCallback, options
      #ifndef _NO_CRYPTO
      , getPassword
      #endif
      );

  RINOK(res);

  updateItems.ClearAndFree();

  return archive.WriteDatabase(EXTERNAL_CODECS_VARS
      newDatabase, options.HeaderMethod, options.HeaderOptions);

  COM_TRY_END
}

static HRESULT ParseBond(UString &srcString, UInt32 &coder, UInt32 &stream)
{
  stream = 0;
  {
    unsigned index = ParseStringToUInt32(srcString, coder);
    if (index == 0)
      return E_INVALIDARG;
    srcString.DeleteFrontal(index);
  }
  if (srcString[0] == 's')
  {
    srcString.Delete(0);
    unsigned index = ParseStringToUInt32(srcString, stream);
    if (index == 0)
      return E_INVALIDARG;
    srcString.DeleteFrontal(index);
  }
  return S_OK;
}

void COutHandler::InitProps()
{
  CMultiMethodProps::Init();

  _removeSfxBlock = false;
  _compressHeaders = true;
  _encryptHeadersSpecified = false;
  _encryptHeaders = false;
  // _useParents = false;
  
  Write_CTime.Init();
  Write_ATime.Init();
  Write_MTime.Init();

  _useMultiThreadMixer = true;

  // _volumeMode = false;

  InitSolid();
  _useTypeSorting = false;
}

HRESULT COutHandler::SetSolidFromString(const UString &s)
{
  UString s2 = s;
  s2.MakeLower_Ascii();
  for (unsigned i = 0; i < s2.Len();)
  {
    const wchar_t *start = ((const wchar_t *)s2) + i;
    const wchar_t *end;
    UInt64 v = ConvertStringToUInt64(start, &end);
    if (start == end)
    {
      if (s2[i++] != 'e')
        return E_INVALIDARG;
      _solidExtension = true;
      continue;
    }
    i += (int)(end - start);
    if (i == s2.Len())
      return E_INVALIDARG;
    wchar_t c = s2[i++];
    if (c == 'f')
    {
      if (v < 1)
        v = 1;
      _numSolidFiles = v;
    }
    else
    {
      unsigned numBits;
      switch (c)
      {
        case 'b': numBits =  0; break;
        case 'k': numBits = 10; break;
        case 'm': numBits = 20; break;
        case 'g': numBits = 30; break;
        case 't': numBits = 40; break;
        default: return E_INVALIDARG;
      }
      _numSolidBytes = (v << numBits);
      _numSolidBytesDefined = true;
    }
  }
  return S_OK;
}

HRESULT COutHandler::SetSolidFromPROPVARIANT(const PROPVARIANT &value)
{
  bool isSolid;
  switch (value.vt)
  {
    case VT_EMPTY: isSolid = true; break;
    case VT_BOOL: isSolid = (value.boolVal != VARIANT_FALSE); break;
    case VT_BSTR:
      if (StringToBool(value.bstrVal, isSolid))
        break;
      return SetSolidFromString(value.bstrVal);
    default: return E_INVALIDARG;
  }
  if (isSolid)
    InitSolid();
  else
    _numSolidFiles = 1;
  return S_OK;
}

static HRESULT PROPVARIANT_to_BoolPair(const PROPVARIANT &prop, CBoolPair &dest)
{
  RINOK(PROPVARIANT_to_bool(prop, dest.Val));
  dest.Def = true;
  return S_OK;
}

HRESULT COutHandler::SetProperty(const wchar_t *nameSpec, const PROPVARIANT &value)
{
  UString name = nameSpec;
  name.MakeLower_Ascii();
  if (name.IsEmpty())
    return E_INVALIDARG;
  
  if (name[0] == L's')
  {
    name.Delete(0);
    if (name.IsEmpty())
      return SetSolidFromPROPVARIANT(value);
    if (value.vt != VT_EMPTY)
      return E_INVALIDARG;
    return SetSolidFromString(name);
  }
  
  UInt32 number;
  int index = ParseStringToUInt32(name, number);
  // UString realName = name.Ptr(index);
  if (index == 0)
  {
    if (name.IsEqualTo("rsfx")) return PROPVARIANT_to_bool(value, _removeSfxBlock);
    if (name.IsEqualTo("hc")) return PROPVARIANT_to_bool(value, _compressHeaders);
    // if (name.IsEqualToNoCase(L"HS")) return PROPVARIANT_to_bool(value, _useParents);
    
    if (name.IsEqualTo("hcf"))
    {
      bool compressHeadersFull = true;
      RINOK(PROPVARIANT_to_bool(value, compressHeadersFull));
      return compressHeadersFull ? S_OK: E_INVALIDARG;
    }
    
    if (name.IsEqualTo("he"))
    {
      RINOK(PROPVARIANT_to_bool(value, _encryptHeaders));
      _encryptHeadersSpecified = true;
      return S_OK;
    }
    
    if (name.IsEqualTo("tc")) return PROPVARIANT_to_BoolPair(value, Write_CTime);
    if (name.IsEqualTo("ta")) return PROPVARIANT_to_BoolPair(value, Write_ATime);
    if (name.IsEqualTo("tm")) return PROPVARIANT_to_BoolPair(value, Write_MTime);
    
    if (name.IsEqualTo("mtf")) return PROPVARIANT_to_bool(value, _useMultiThreadMixer);

    if (name.IsEqualTo("qs")) return PROPVARIANT_to_bool(value, _useTypeSorting);

    // if (name.IsEqualTo("v"))  return PROPVARIANT_to_bool(value, _volumeMode);
  }
  return CMultiMethodProps::SetProperty(name, value);
}

STDMETHODIMP CHandler::SetProperties(const wchar_t * const *names, const PROPVARIANT *values, UInt32 numProps)
{
  COM_TRY_BEGIN
  _bonds.Clear();
  InitProps();

  for (UInt32 i = 0; i < numProps; i++)
  {
    UString name = names[i];
    name.MakeLower_Ascii();
    if (name.IsEmpty())
      return E_INVALIDARG;

    const PROPVARIANT &value = values[i];

    if (name[0] == 'b')
    {
      if (value.vt != VT_EMPTY)
        return E_INVALIDARG;
      name.Delete(0);
      
      CBond2 bond;
      RINOK(ParseBond(name, bond.OutCoder, bond.OutStream));
      if (name[0] != ':')
        return E_INVALIDARG;
      name.Delete(0);
      UInt32 inStream = 0;
      RINOK(ParseBond(name, bond.InCoder, inStream));
      if (inStream != 0)
        return E_INVALIDARG;
      if (!name.IsEmpty())
        return E_INVALIDARG;
      _bonds.Add(bond);
      continue;
    }

    RINOK(SetProperty(name, value));
  }

  unsigned numEmptyMethods = GetNumEmptyMethods();
  if (numEmptyMethods > 0)
  {
    unsigned k;
    for (k = 0; k < _bonds.Size(); k++)
    {
      const CBond2 &bond = _bonds[k];
      if (bond.InCoder < (UInt32)numEmptyMethods ||
          bond.OutCoder < (UInt32)numEmptyMethods)
        return E_INVALIDARG;
    }
    for (k = 0; k < _bonds.Size(); k++)
    {
      CBond2 &bond = _bonds[k];
      bond.InCoder -= (UInt32)numEmptyMethods;
      bond.OutCoder -= (UInt32)numEmptyMethods;
    }
    _methods.DeleteFrontal(numEmptyMethods);
  }
  
  FOR_VECTOR (k, _bonds)
  {
    const CBond2 &bond = _bonds[k];
    if (bond.InCoder >= (UInt32)_methods.Size() ||
        bond.OutCoder >= (UInt32)_methods.Size())
      return E_INVALIDARG;
  }

  return S_OK;
  COM_TRY_END
}

}}
