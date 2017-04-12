// 7zDecode.cpp

#include "StdAfx.h"

#include "../../Common/LimitedStreams.h"
#include "../../Common/ProgressUtils.h"
#include "../../Common/StreamObjects.h"

#include "7zDecode.h"

namespace NArchive {
namespace N7z {

class CDecProgress:
  public ICompressProgressInfo,
  public CMyUnknownImp
{
  CMyComPtr<ICompressProgressInfo> _progress;
public:
  CDecProgress(ICompressProgressInfo *progress): _progress(progress) {}
  
  MY_UNKNOWN_IMP1(ICompressProgressInfo)
  STDMETHOD(SetRatioInfo)(const UInt64 *inSize, const UInt64 *outSize);
};

STDMETHODIMP CDecProgress::SetRatioInfo(const UInt64 * /* inSize */, const UInt64 *outSize)
{
  return _progress->SetRatioInfo(NULL, outSize);
}

static void Convert_FolderInfo_to_BindInfo(const CFolderEx &folder, CBindInfoEx &bi)
{
  bi.Clear();
  
  bi.Bonds.ClearAndSetSize(folder.Bonds.Size());
  unsigned i;
  for (i = 0; i < folder.Bonds.Size(); i++)
  {
    NCoderMixer2::CBond &bond = bi.Bonds[i];
    const N7z::CBond &folderBond = folder.Bonds[i];
    bond.PackIndex = folderBond.PackIndex;
    bond.UnpackIndex = folderBond.UnpackIndex;
  }

  bi.Coders.ClearAndSetSize(folder.Coders.Size());
  bi.CoderMethodIDs.ClearAndSetSize(folder.Coders.Size());
  for (i = 0; i < folder.Coders.Size(); i++)
  {
    const CCoderInfo &coderInfo = folder.Coders[i];
    bi.Coders[i].NumStreams = coderInfo.NumStreams;
    bi.CoderMethodIDs[i] = coderInfo.MethodID;
  }
  
  /*
  if (!bi.SetUnpackCoder())
    throw 1112;
  */
  bi.UnpackCoder = folder.UnpackCoder;
  bi.PackStreams.ClearAndSetSize(folder.PackStreams.Size());
  for (i = 0; i < folder.PackStreams.Size(); i++)
    bi.PackStreams[i] = folder.PackStreams[i];
}

static inline bool AreCodersEqual(
    const NCoderMixer2::CCoderStreamsInfo &a1,
    const NCoderMixer2::CCoderStreamsInfo &a2)
{
  return (a1.NumStreams == a2.NumStreams);
}

static inline bool AreBondsEqual(
    const NCoderMixer2::CBond &a1,
    const NCoderMixer2::CBond &a2)
{
  return
    (a1.PackIndex == a2.PackIndex) &&
    (a1.UnpackIndex == a2.UnpackIndex);
}

static bool AreBindInfoExEqual(const CBindInfoEx &a1, const CBindInfoEx &a2)
{
  if (a1.Coders.Size() != a2.Coders.Size())
    return false;
  unsigned i;
  for (i = 0; i < a1.Coders.Size(); i++)
    if (!AreCodersEqual(a1.Coders[i], a2.Coders[i]))
      return false;
  
  if (a1.Bonds.Size() != a2.Bonds.Size())
    return false;
  for (i = 0; i < a1.Bonds.Size(); i++)
    if (!AreBondsEqual(a1.Bonds[i], a2.Bonds[i]))
      return false;
  
  for (i = 0; i < a1.CoderMethodIDs.Size(); i++)
    if (a1.CoderMethodIDs[i] != a2.CoderMethodIDs[i])
      return false;
  
  if (a1.PackStreams.Size() != a2.PackStreams.Size())
    return false;
  for (i = 0; i < a1.PackStreams.Size(); i++)
    if (a1.PackStreams[i] != a2.PackStreams[i])
      return false;

  /*
  if (a1.UnpackCoder != a2.UnpackCoder)
    return false;
  */
  return true;
}

CDecoder::CDecoder(bool useMixerMT):
    _bindInfoPrev_Defined(false),
    _useMixerMT(useMixerMT)
{}


struct CLockedInStream:
  public IUnknown,
  public CMyUnknownImp
{
  CMyComPtr<IInStream> Stream;
  UInt64 Pos;

  MY_UNKNOWN_IMP

  #ifdef USE_MIXER_MT
  NWindows::NSynchronization::CCriticalSection CriticalSection;
  #endif
};


#ifdef USE_MIXER_MT

class CLockedSequentialInStreamMT:
  public ISequentialInStream,
  public CMyUnknownImp
{
  CLockedInStream *_glob;
  UInt64 _pos;
  CMyComPtr<IUnknown> _globRef;
public:
  void Init(CLockedInStream *lockedInStream, UInt64 startPos)
  {
    _globRef = lockedInStream;
    _glob = lockedInStream;
    _pos = startPos;
  }

  MY_UNKNOWN_IMP1(ISequentialInStream)

  STDMETHOD(Read)(void *data, UInt32 size, UInt32 *processedSize);
};

STDMETHODIMP CLockedSequentialInStreamMT::Read(void *data, UInt32 size, UInt32 *processedSize)
{
  NWindows::NSynchronization::CCriticalSectionLock lock(_glob->CriticalSection);

  if (_pos != _glob->Pos)
  {
    RINOK(_glob->Stream->Seek(_pos, STREAM_SEEK_SET, NULL));
    _glob->Pos = _pos;
  }

  UInt32 realProcessedSize = 0;
  HRESULT res = _glob->Stream->Read(data, size, &realProcessedSize);
  _pos += realProcessedSize;
  _glob->Pos = _pos;
  if (processedSize)
    *processedSize = realProcessedSize;
  return res;
}

#endif


#ifdef USE_MIXER_ST

class CLockedSequentialInStreamST:
  public ISequentialInStream,
  public CMyUnknownImp
{
  CLockedInStream *_glob;
  UInt64 _pos;
  CMyComPtr<IUnknown> _globRef;
public:
  void Init(CLockedInStream *lockedInStream, UInt64 startPos)
  {
    _globRef = lockedInStream;
    _glob = lockedInStream;
    _pos = startPos;
  }

  MY_UNKNOWN_IMP1(ISequentialInStream)

  STDMETHOD(Read)(void *data, UInt32 size, UInt32 *processedSize);
};

STDMETHODIMP CLockedSequentialInStreamST::Read(void *data, UInt32 size, UInt32 *processedSize)
{
  if (_pos != _glob->Pos)
  {
    RINOK(_glob->Stream->Seek(_pos, STREAM_SEEK_SET, NULL));
    _glob->Pos = _pos;
  }

  UInt32 realProcessedSize = 0;
  HRESULT res = _glob->Stream->Read(data, size, &realProcessedSize);
  _pos += realProcessedSize;
  _glob->Pos = _pos;
  if (processedSize)
    *processedSize = realProcessedSize;
  return res;
}

#endif



HRESULT CDecoder::Decode(
    DECL_EXTERNAL_CODECS_LOC_VARS
    IInStream *inStream,
    UInt64 startPos,
    const CFolders &folders, unsigned folderIndex,
    const UInt64 *unpackSize

    , ISequentialOutStream *outStream
    , ICompressProgressInfo *compressProgress
    , ISequentialInStream **

    #ifdef USE_MIXER_ST
    inStreamMainRes
    #endif
    
    _7Z_DECODER_CRYPRO_VARS_DECL

    #if !defined(_7ZIP_ST) && !defined(_SFX)
    , bool mtMode, UInt32 numThreads
    #endif
    )
{
  const UInt64 *packPositions = &folders.PackPositions[folders.FoStartPackStreamIndex[folderIndex]];
  CFolderEx folderInfo;
  folders.ParseFolderEx(folderIndex, folderInfo);

  if (!folderInfo.IsDecodingSupported())
    return E_NOTIMPL;

  CBindInfoEx bindInfo;
  Convert_FolderInfo_to_BindInfo(folderInfo, bindInfo);
  if (!bindInfo.CalcMapsAndCheck())
    return E_NOTIMPL;
  
  UInt64 folderUnpackSize = folders.GetFolderUnpackSize(folderIndex);
  bool fullUnpack = true;
  if (unpackSize)
  {
    if (*unpackSize > folderUnpackSize)
      return E_FAIL;
    fullUnpack = (*unpackSize == folderUnpackSize);
  }

  /*
  We don't need to init isEncrypted and passwordIsDefined
  We must upgrade them only
  
  #ifndef _NO_CRYPTO
  isEncrypted = false;
  passwordIsDefined = false;
  #endif
  */
  
  if (!_bindInfoPrev_Defined || !AreBindInfoExEqual(bindInfo, _bindInfoPrev))
  {
    _mixerRef.Release();

    #ifdef USE_MIXER_MT
    #ifdef USE_MIXER_ST
    if (_useMixerMT)
    #endif
    {
      _mixerMT = new NCoderMixer2::CMixerMT(false);
      _mixerRef = _mixerMT;
      _mixer = _mixerMT;
    }
    #ifdef USE_MIXER_ST
    else
    #endif
    #endif
    {
      #ifdef USE_MIXER_ST
      _mixerST = new NCoderMixer2::CMixerST(false);
      _mixerRef = _mixerST;
      _mixer = _mixerST;
      #endif
    }
    
    RINOK(_mixer->SetBindInfo(bindInfo));
    
    FOR_VECTOR(i, folderInfo.Coders)
    {
      const CCoderInfo &coderInfo = folderInfo.Coders[i];

      #ifndef _SFX
      // we don't support RAR codecs here
      if ((coderInfo.MethodID >> 8) == 0x403)
        return E_NOTIMPL;
      #endif
  
      CCreatedCoder cod;
      RINOK(CreateCoder(
          EXTERNAL_CODECS_LOC_VARS
          coderInfo.MethodID, false, cod));
    
      if (coderInfo.IsSimpleCoder())
      {
        if (!cod.Coder)
          return E_NOTIMPL;
        // CMethodId m = coderInfo.MethodID;
        // isFilter = (IsFilterMethod(m) || m == k_AES);
      }
      else
      {
        if (!cod.Coder2 || cod.NumStreams != coderInfo.NumStreams)
          return E_NOTIMPL;
      }
      _mixer->AddCoder(cod);
      
      // now there is no codec that uses another external codec
      /*
      #ifdef EXTERNAL_CODECS
      CMyComPtr<ISetCompressCodecsInfo> setCompressCodecsInfo;
      decoderUnknown.QueryInterface(IID_ISetCompressCodecsInfo, (void **)&setCompressCodecsInfo);
      if (setCompressCodecsInfo)
      {
        // we must use g_ExternalCodecs also
        RINOK(setCompressCodecsInfo->SetCompressCodecsInfo(__externalCodecs->GetCodecs));
      }
      #endif
      */
    }
    
    _bindInfoPrev = bindInfo;
    _bindInfoPrev_Defined = true;
  }

  _mixer->ReInit();
  
  UInt32 packStreamIndex = 0;
  UInt32 unpackStreamIndexStart = folders.FoToCoderUnpackSizes[folderIndex];

  unsigned i;

  for (i = 0; i < folderInfo.Coders.Size(); i++)
  {
    const CCoderInfo &coderInfo = folderInfo.Coders[i];
    IUnknown *decoder = _mixer->GetCoder(i).GetUnknown();

    {
      CMyComPtr<ICompressSetDecoderProperties2> setDecoderProperties;
      decoder->QueryInterface(IID_ICompressSetDecoderProperties2, (void **)&setDecoderProperties);
      if (setDecoderProperties)
      {
        const CByteBuffer &props = coderInfo.Props;
        size_t size = props.Size();
        if (size > 0xFFFFFFFF)
          return E_NOTIMPL;
        HRESULT res = setDecoderProperties->SetDecoderProperties2((const Byte *)props, (UInt32)size);
        if (res == E_INVALIDARG)
          res = E_NOTIMPL;
        RINOK(res);
      }
    }

    #if !defined(_7ZIP_ST) && !defined(_SFX)
    if (mtMode)
    {
      CMyComPtr<ICompressSetCoderMt> setCoderMt;
      decoder->QueryInterface(IID_ICompressSetCoderMt, (void **)&setCoderMt);
      if (setCoderMt)
      {
        RINOK(setCoderMt->SetNumberOfThreads(numThreads));
      }
    }
    #endif

    #ifndef _NO_CRYPTO
    {
      CMyComPtr<ICryptoSetPassword> cryptoSetPassword;
      decoder->QueryInterface(IID_ICryptoSetPassword, (void **)&cryptoSetPassword);
      if (cryptoSetPassword)
      {
        isEncrypted = true;
        if (!getTextPassword)
          return E_NOTIMPL;
        CMyComBSTR passwordBSTR;
        RINOK(getTextPassword->CryptoGetTextPassword(&passwordBSTR));
        passwordIsDefined = true;
        password.Empty();
        size_t len = 0;
        if (passwordBSTR)
        {
          password = passwordBSTR;
          len = password.Len();
        }
        CByteBuffer buffer(len * 2);
        for (size_t k = 0; k < len; k++)
        {
          wchar_t c = passwordBSTR[k];
          ((Byte *)buffer)[k * 2] = (Byte)c;
          ((Byte *)buffer)[k * 2 + 1] = (Byte)(c >> 8);
        }
        RINOK(cryptoSetPassword->CryptoSetPassword((const Byte *)buffer, (UInt32)buffer.Size()));
      }
    }
    #endif

    {
      CMyComPtr<ICompressSetFinishMode> setFinishMode;
      decoder->QueryInterface(IID_ICompressSetFinishMode, (void **)&setFinishMode);
      if (setFinishMode)
      {
        RINOK(setFinishMode->SetFinishMode(BoolToInt(fullUnpack)));
      }
    }
    
    UInt32 numStreams = (UInt32)coderInfo.NumStreams;
    
    CObjArray<UInt64> packSizes(numStreams);
    CObjArray<const UInt64 *> packSizesPointers(numStreams);
       
    for (UInt32 j = 0; j < numStreams; j++, packStreamIndex++)
    {
      int bond = folderInfo.FindBond_for_PackStream(packStreamIndex);
      
      if (bond >= 0)
        packSizesPointers[j] = &folders.CoderUnpackSizes[unpackStreamIndexStart + folderInfo.Bonds[(unsigned)bond].UnpackIndex];
      else
      {
        int index = folderInfo.Find_in_PackStreams(packStreamIndex);
        if (index < 0)
          return E_NOTIMPL;
        packSizes[j] = packPositions[(unsigned)index + 1] - packPositions[(unsigned)index];
        packSizesPointers[j] = &packSizes[j];
      }
    }

    const UInt64 *unpackSizesPointer =
        (unpackSize && i == bindInfo.UnpackCoder) ?
            unpackSize :
            &folders.CoderUnpackSizes[unpackStreamIndexStart + i];
    
    _mixer->SetCoderInfo(i, unpackSizesPointer, packSizesPointers);
  }

  if (outStream)
  {
    _mixer->SelectMainCoder(!fullUnpack);
  }

  CObjectVector< CMyComPtr<ISequentialInStream> > inStreams;
  
  CLockedInStream *lockedInStreamSpec = new CLockedInStream;
  CMyComPtr<IUnknown> lockedInStream = lockedInStreamSpec;

  bool needMtLock = false;

  if (folderInfo.PackStreams.Size() > 1)
  {
    // lockedInStream.Pos = (UInt64)(Int64)-1;
    // RINOK(inStream->Seek(0, STREAM_SEEK_CUR, &lockedInStream.Pos));
    RINOK(inStream->Seek(startPos + packPositions[0], STREAM_SEEK_SET, &lockedInStreamSpec->Pos));
    lockedInStreamSpec->Stream = inStream;

    #ifdef USE_MIXER_ST
    if (_mixer->IsThere_ExternalCoder_in_PackTree(_mixer->MainCoderIndex))
    #endif
      needMtLock = true;
  }

  for (unsigned j = 0; j < folderInfo.PackStreams.Size(); j++)
  {
    CMyComPtr<ISequentialInStream> packStream;
    UInt64 packPos = startPos + packPositions[j];

    if (folderInfo.PackStreams.Size() == 1)
    {
      RINOK(inStream->Seek(packPos, STREAM_SEEK_SET, NULL));
      packStream = inStream;
    }
    else
    {
      #ifdef USE_MIXER_MT
      #ifdef USE_MIXER_ST
      if (_useMixerMT || needMtLock)
      #endif
      {
        CLockedSequentialInStreamMT *lockedStreamImpSpec = new CLockedSequentialInStreamMT;
        packStream = lockedStreamImpSpec;
        lockedStreamImpSpec->Init(lockedInStreamSpec, packPos);
      }
      #ifdef USE_MIXER_ST
      else
      #endif
      #endif
      {
        #ifdef USE_MIXER_ST
        CLockedSequentialInStreamST *lockedStreamImpSpec = new CLockedSequentialInStreamST;
        packStream = lockedStreamImpSpec;
        lockedStreamImpSpec->Init(lockedInStreamSpec, packPos);
        #endif
      }
    }

    CLimitedSequentialInStream *streamSpec = new CLimitedSequentialInStream;
    inStreams.AddNew() = streamSpec;
    streamSpec->SetStream(packStream);
    streamSpec->Init(packPositions[j + 1] - packPositions[j]);
  }
  
  unsigned num = inStreams.Size();
  CObjArray<ISequentialInStream *> inStreamPointers(num);
  for (i = 0; i < num; i++)
    inStreamPointers[i] = inStreams[i];

  if (outStream)
  {
    CMyComPtr<ICompressProgressInfo> progress2;
    if (compressProgress && !_mixer->Is_PackSize_Correct_for_Coder(_mixer->MainCoderIndex))
      progress2 = new CDecProgress(compressProgress);

    ISequentialOutStream *outStreamPointer = outStream;
    return _mixer->Code(inStreamPointers, &outStreamPointer, progress2 ? (ICompressProgressInfo *)progress2 : compressProgress);
  }
  
  #ifdef USE_MIXER_ST
    return _mixerST->GetMainUnpackStream(inStreamPointers, inStreamMainRes);
  #else
    return E_FAIL;
  #endif
}

}}
