// 7zItem.h

#ifndef __7Z_ITEM_H
#define __7Z_ITEM_H

#include "../../../Common/MyBuffer.h"
#include "../../../Common/MyString.h"

#include "../../Common/MethodId.h"

#include "7zHeader.h"

namespace NArchive {
namespace N7z {

typedef UInt32 CNum;
const CNum kNumMax     = 0x7FFFFFFF;
const CNum kNumNoIndex = 0xFFFFFFFF;

struct CCoderInfo
{
  CMethodId MethodID;
  CByteBuffer Props;
  UInt32 NumStreams;
  
  bool IsSimpleCoder() const { return NumStreams == 1; }
};

struct CBond
{
  UInt32 PackIndex;
  UInt32 UnpackIndex;
};

struct CFolder
{
  CLASS_NO_COPY(CFolder)
public:
  CObjArray2<CCoderInfo> Coders;
  CObjArray2<CBond> Bonds;
  CObjArray2<UInt32> PackStreams;

  CFolder() {}

  bool IsDecodingSupported() const { return Coders.Size() <= 32; }

  int Find_in_PackStreams(UInt32 packStream) const
  {
    FOR_VECTOR(i, PackStreams)
      if (PackStreams[i] == packStream)
        return i;
    return -1;
  }

  int FindBond_for_PackStream(UInt32 packStream) const
  {
    FOR_VECTOR(i, Bonds)
      if (Bonds[i].PackIndex == packStream)
        return i;
    return -1;
  }
  
  /*
  int FindBond_for_UnpackStream(UInt32 unpackStream) const
  {
    FOR_VECTOR(i, Bonds)
      if (Bonds[i].UnpackIndex == unpackStream)
        return i;
    return -1;
  }

  int FindOutCoder() const
  {
    for (int i = (int)Coders.Size() - 1; i >= 0; i--)
      if (FindBond_for_UnpackStream(i) < 0)
        return i;
    return -1;
  }
  */

  bool IsEncrypted() const
  {
    FOR_VECTOR(i, Coders)
      if (Coders[i].MethodID == k_AES)
        return true;
    return false;
  }
};

struct CUInt32DefVector
{
  CBoolVector Defs;
  CRecordVector<UInt32> Vals;

  void ClearAndSetSize(unsigned newSize)
  {
    Defs.ClearAndSetSize(newSize);
    Vals.ClearAndSetSize(newSize);
  }

  void Clear()
  {
    Defs.Clear();
    Vals.Clear();
  }

  void ReserveDown()
  {
    Defs.ReserveDown();
    Vals.ReserveDown();
  }

  bool ValidAndDefined(unsigned i) const { return i < Defs.Size() && Defs[i]; }
};

struct CUInt64DefVector
{
  CBoolVector Defs;
  CRecordVector<UInt64> Vals;
  
  void Clear()
  {
    Defs.Clear();
    Vals.Clear();
  }
  
  void ReserveDown()
  {
    Defs.ReserveDown();
    Vals.ReserveDown();
  }

  bool GetItem(unsigned index, UInt64 &value) const
  {
    if (index < Defs.Size() && Defs[index])
    {
      value = Vals[index];
      return true;
    }
    value = 0;
    return false;
  }
  
  void SetItem(unsigned index, bool defined, UInt64 value);

  bool CheckSize(unsigned size) const { return Defs.Size() == size || Defs.Size() == 0; }
};

struct CFileItem
{
  UInt64 Size;
  UInt32 Attrib;
  UInt32 Crc;
  /*
  int Parent;
  bool IsAltStream;
  */
  bool HasStream; // Test it !!! it means that there is
                  // stream in some folder. It can be empty stream
  bool IsDir;
  bool CrcDefined;
  bool AttribDefined;

  CFileItem():
    /*
    Parent(-1),
    IsAltStream(false),
    */
    HasStream(true),
    IsDir(false),
    CrcDefined(false),
    AttribDefined(false)
      {}
  void SetAttrib(UInt32 attrib)
  {
    AttribDefined = true;
    Attrib = attrib;
  }
};

}}

#endif
