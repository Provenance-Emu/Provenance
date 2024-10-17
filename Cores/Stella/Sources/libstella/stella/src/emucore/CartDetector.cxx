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

#include "bspf.hxx"
#include "Logger.hxx"

#include "CartDetector.hxx"
#include "CartMVC.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Bankswitch::Type CartDetector::autodetectType(const ByteBuffer& image, size_t size)
{
  // Guess type based on size
  Bankswitch::Type type = Bankswitch::Type::_AUTO;

  if((size % 8448) == 0 || size == 6_KB)
  {
    if(size == 6_KB && isProbablyGL(image, size))
      type = Bankswitch::Type::_GL;
    else
      type = Bankswitch::Type::_AR;
  }
  else if((size <= 2_KB) ||
          (size == 4_KB && std::memcmp(image.get(), image.get() + 2_KB, 2_KB) == 0))
  {
    type = isProbablyCV(image, size) ? Bankswitch::Type::_CV : Bankswitch::Type::_2K;
  }
  else if(size == 4_KB)
  {
    if(isProbablyCV(image, size))
      type = Bankswitch::Type::_CV;
    else if(isProbably4KSC(image, size))
      type = Bankswitch::Type::_4KSC;
    else if (isProbablyFC(image, size))
      type = Bankswitch::Type::_FC;
    else if (isProbablyGL(image, size))
      type = Bankswitch::Type::_GL;
    else
      type = Bankswitch::Type::_4K;
  }
  else if(size == 8_KB)
  {
    // First check for *potential* F8
    static constexpr uInt8 signature[2][3] = {
      { 0x8D, 0xF9, 0x1F },  // STA $1FF9
      { 0x8D, 0xF9, 0xFF }   // STA $FFF9
    };
    const bool f8 = searchForBytes(image, size, signature[0], 3, 2) ||
                    searchForBytes(image, size, signature[1], 3, 2);

    if(isProbablySC(image, size))
      type = Bankswitch::Type::_F8SC;
    else if(std::memcmp(image.get(), image.get() + 4_KB, 4_KB) == 0)
      type = Bankswitch::Type::_4K;
    else if(isProbablyE0(image, size))
      type = Bankswitch::Type::_E0;
    else if(isProbably3EX(image, size))
      type = Bankswitch::Type::_3EX;
    else if(isProbably3E(image, size))
      type = Bankswitch::Type::_3E;
    else if(isProbably3F(image, size))
      type = Bankswitch::Type::_3F;
    else if(isProbablyUA(image, size))
      type = Bankswitch::Type::_UA;
    else if(isProbably0FA0(image, size))
      type = Bankswitch::Type::_0FA0;
    else if(isProbablyFE(image, size) && !f8)
      type = Bankswitch::Type::_FE;
    else if(isProbably0840(image, size))
      type = Bankswitch::Type::_0840;
    else if(isProbablyE78K(image, size))
      type = Bankswitch::Type::_E7;
    else if (isProbablyWD(image,size))
      type = Bankswitch::Type::_WD;
    else if (isProbablyFC(image, size))
      type = Bankswitch::Type::_FC;
    else if(isProbably03E0(image, size))
      type = Bankswitch::Type::_03E0;
    else
      type = Bankswitch::Type::_F8;
  }
  else if(size == 8_KB + 3)  // 8195 bytes (Experimental)
  {
    type = Bankswitch::Type::_WDSW;
  }
  else if(size >= 10_KB && size <= 10_KB + 256)  // ~10K - Pitfall2
  {
    type = Bankswitch::Type::_DPC;
  }
  else if(size == 12_KB)
  {
    if(isProbablyE7(image, size))
      type = Bankswitch::Type::_E7;
    else
      type = Bankswitch::Type::_FA;
  }
  else if(size == 16_KB)
  {
    if(isProbablySC(image, size))
      type = Bankswitch::Type::_F6SC;
    else if(isProbablyE7(image, size))
      type = Bankswitch::Type::_E7;
    else if (isProbablyFC(image, size))
      type = Bankswitch::Type::_FC;
    else if(isProbably3EX(image, size))
      type = Bankswitch::Type::_3EX;
    else if(isProbably3E(image, size))
      type = Bankswitch::Type::_3E;
  /* no known 16K 3F ROMS
    else if(isProbably3F(image, size))
      type = Bankswitch::Type::_3F;
  */
    else
      type = Bankswitch::Type::_F6;
  }
  else if(size == 24_KB || size == 28_KB)
  {
    type = Bankswitch::Type::_FA2;
  }
  else if(size == 29_KB)
  {
    if(isProbablyARM(image, size))
      type = Bankswitch::Type::_FA2;
    else /*if(isProbablyDPCplus(image, size))*/
      type = Bankswitch::Type::_DPCP;
  }
  else if(size == 32_KB)
  {
    if (isProbablyCTY(image, size))
      type = Bankswitch::Type::_CTY;
    else if(isProbablyCDF(image, size))
      type = Bankswitch::Type::_CDF;
    else if(isProbablyDPCplus(image, size))
      type = Bankswitch::Type::_DPCP;
    else if(isProbablySC(image, size))
      type = Bankswitch::Type::_F4SC;
    else if(isProbably3EX(image, size))
      type = Bankswitch::Type::_3EX;
    else if(isProbably3E(image, size))
      type = Bankswitch::Type::_3E;
    else if(isProbably3F(image, size))
      type = Bankswitch::Type::_3F;
    else if (isProbablyBUS(image, size))
      type = Bankswitch::Type::_BUS;
    else if(isProbablyFA2(image, size))
      type = Bankswitch::Type::_FA2;
    else if (isProbablyFC(image, size))
      type = Bankswitch::Type::_FC;
    else
      type = Bankswitch::Type::_F4;
  }
  else if(size == 60_KB)
  {
    if(isProbablyCTY(image, size))
      type = Bankswitch::Type::_CTY;
    else
      type = Bankswitch::Type::_F4;
  }
  else if(size == 64_KB)
  {
    if (isProbablyCDF(image, size))
      type = Bankswitch::Type::_CDF;
    else if(isProbably3EX(image, size))
      type = Bankswitch::Type::_3EX;
    else if(isProbably3E(image, size))
      type = Bankswitch::Type::_3E;
    else if(isProbably3F(image, size))
      type = Bankswitch::Type::_3F;
    else if(isProbably4A50(image, size))
      type = Bankswitch::Type::_4A50;
    else if(isProbablyEF(image, size, type))
      ; // type has been set directly in the function
    else if(isProbablyX07(image, size))
      type = Bankswitch::Type::_X07;
    else
      type = Bankswitch::Type::_F0;
  }
  else if(size == 128_KB)
  {
    if (isProbablyCDF(image, size))
      type = Bankswitch::Type::_CDF;
    else if(isProbably3EX(image, size))
      type = Bankswitch::Type::_3EX;
    else if(isProbably3E(image, size))
      type = Bankswitch::Type::_3E;
    else if(isProbablyDF(image, size, type))
      ; // type has been set directly in the function
    else if(isProbably3F(image, size))
      type = Bankswitch::Type::_3F;
    else if(isProbably4A50(image, size))
      type = Bankswitch::Type::_4A50;
    else /*if(isProbablySB(image, size))*/
      type = Bankswitch::Type::_SB;
  }
  else if(size == 256_KB)
  {
    if (isProbablyCDF(image, size))
      type = Bankswitch::Type::_CDF;
    else if(isProbably3EX(image, size))
      type = Bankswitch::Type::_3EX;
    else if(isProbably3E(image, size))
      type = Bankswitch::Type::_3E;
    else if(isProbablyBF(image, size, type))
      ; // type has been set directly in the function
    else if(isProbably3F(image, size))
      type = Bankswitch::Type::_3F;
    else /*if(isProbablySB(image, size))*/
      type = Bankswitch::Type::_SB;
  }
  else if(size == 512_KB)
  {
    if(isProbablyTVBoy(image, size))
      type = Bankswitch::Type::_TVBOY;
    else if (isProbablyCDF(image, size))
      type = Bankswitch::Type::_CDF;
    else if(isProbably3EX(image, size))
      type = Bankswitch::Type::_3EX;
    else if(isProbably3E(image, size))
      type = Bankswitch::Type::_3E;
    else if(isProbably3F(image, size))
      type = Bankswitch::Type::_3F;
  }
  else  // what else can we do?
  {
    if(isProbably3EX(image, size))
      type = Bankswitch::Type::_3EX;
    else if(isProbably3E(image, size))
      type = Bankswitch::Type::_3E;
    else if(isProbably3F(image, size))
      type = Bankswitch::Type::_3F;
  }

  // Variable sized ROM formats are independent of image size and come last
  if(isProbably3EPlus(image, size))
    type = Bankswitch::Type::_3EP;
  else if(isProbablyMDM(image, size))
    type = Bankswitch::Type::_MDM;
  else if(isProbablyMVC(image, size))
    type = Bankswitch::Type::_MVC;

  // If we get here and autodetection failed, then we force '4K'
  if(type == Bankswitch::Type::_AUTO)
    type = Bankswitch::Type::_4K;  // Most common bankswitching type

  ostringstream ss;
  ss << "Bankswitching type '" << Bankswitch::typeToDesc(type) << "' detected";
  Logger::debug(ss.str());

  return type;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::searchForBytes(const uInt8* image, size_t imagesize,
                                  const uInt8* signature, uInt32 sigsize,
                                  uInt32 minhits)
{
  uInt32 count{0};

  for(uInt32 i = 0; i < imagesize - sigsize; ++i)
  {
    uInt32 j{0};

    for(j = 0; j < sigsize; ++j)
    {
      if(image[i + j] != signature[j])
        break;
    }
    if(j == sigsize)
    {
      if(++count == minhits)
        break;
      i += sigsize;  // skip past this signature 'window' entirely
    }
  }

  return (count == minhits);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablySC(const ByteBuffer& image, size_t size)
{
  // We assume a Superchip cart repeats the first 128 bytes for the second
  // 128 bytes in the RAM area, which is the first 256 bytes of each 4K bank
  const uInt8* ptr = image.get();
  while(size)
  {
    if(std::memcmp(ptr, ptr + 128, 128) != 0)
      return false;

    ptr  += 4_KB;
    size -= 4_KB;
  }
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyARM(const ByteBuffer& image, size_t size)
{
  // ARM code contains the following 'loader' patterns in the first 1K
  // Thanks to Thomas Jentzsch of AtariAge for this advice
  static constexpr uInt8 signature[2][4] = {
    { 0xA0, 0xC1, 0x1F, 0xE0 },
    { 0x00, 0x80, 0x02, 0xE0 }
  };
  if(searchForBytes(image, std::min<size_t>(size, 1_KB), signature[0], 4))
    return true;
  else
    return searchForBytes(image, std::min<size_t>(size, 1_KB), signature[1], 4);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbably03E0(const ByteBuffer& image, size_t size)
{
  // 03E0 cart bankswitching for Brazilian Parker Bros ROMs, switches segment
  // 0 into bank 0 by accessing address 0x3E0 using 'LDA $3E0' or 'ORA $3E0'.
  static constexpr uInt8 signature[2][4] = {
    { 0x0D, 0xE0, 0x03, 0x0D },  // ORA $3E0, ORA (Popeye)
    { 0xAD, 0xE0, 0x03, 0xAD }   // LDA $3E0, ORA (Montezuma's Revenge)
  };
  for(const auto* const sig: signature)
    if(searchForBytes(image, size, sig, 4))
      return true;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbably0840(const ByteBuffer& image, size_t size)
{
  // 0840 cart bankswitching is triggered by accessing addresses 0x0800
  // or 0x0840 at least twice
  static constexpr uInt8 signature1[3][3] = {
    { 0xAD, 0x00, 0x08 },  // LDA $0800
    { 0xAD, 0x40, 0x08 },  // LDA $0840
    { 0x2C, 0x00, 0x08 }   // BIT $0800
  };
  for(const auto* const sig: signature1)
    if(searchForBytes(image, size, sig, 3, 2))
      return true;

  static constexpr uInt8 signature2[2][4] = {
    { 0x0C, 0x00, 0x08, 0x4C },  // NOP $0800; JMP ...
    { 0x0C, 0xFF, 0x0F, 0x4C }   // NOP $0FFF; JMP ...
  };
  for(const auto* const sig: signature2)
    if(searchForBytes(image, size, sig, 4, 2))
      return true;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbably0FA0(const ByteBuffer& image, size_t size)
{
  // Other Brazilian (Fotomania) ROM's bankswitching switches to bank 1 by
  // accessing address 0xFC0 using 'BIT $FC0', 'BIT $FC0' or 'STA $FC0'
  // Also a game (Motocross) using 'BIT $EFC0' has been found
  static constexpr uInt8 signature[4][3] = {
    { 0x2C, 0xC0, 0x0F },  // BIT $FC0  (H.E.R.O., Kung-Fu Master)
    { 0x8D, 0xC0, 0x0F },  // STA $FC0  (Pole Position, Subterranea)
    { 0xAD, 0xC0, 0x0F },  // LDA $FC0  (Front Line, Zaxxon)
    { 0x2C, 0xC0, 0xEF }   // BIT $EFC0 (Motocross)
  };
  for(const auto* const sig: signature)
    if(searchForBytes(image, size, sig, 3))
      return true;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbably3E(const ByteBuffer& image, size_t size)
{
  // 3E cart RAM bankswitching is triggered by storing the bank number
  // in address 3E using 'STA $3E', ROM bankswitching is triggered by
  // storing the bank number in address 3F using 'STA $3F'.
  // We expect the latter will be present at least 2 times, since there
  // are at least two banks

  static constexpr uInt8 signature1[] = { 0x85, 0x3E };  // STA $3E
  static constexpr uInt8 signature2[] = { 0x85, 0x3F };  // STA $3F
  return searchForBytes(image, size, signature1, 2)
    && searchForBytes(image, size, signature2, 2, 2);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbably3EX(const ByteBuffer& image, size_t size)
{
  // 3EX cart have at least 2 occurrences of the string "3EX"
  static constexpr uInt8 _3EX[] = { '3', 'E', 'X' };
  return searchForBytes(image, size, _3EX, 3, 2);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbably3EPlus(const ByteBuffer& image, size_t size)
{
  // 3E+ cart is identified key 'TJ3E' in the ROM
  static constexpr uInt8 tj3e[] = { 'T', 'J', '3', 'E' };
  return searchForBytes(image, size, tj3e, 4);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbably3F(const ByteBuffer& image, size_t size)
{
  // 3F cart bankswitching is triggered by storing the bank number
  // in address 3F using 'STA $3F'
  // We expect it will be present at least 2 times, since there are
  // at least two banks
  static constexpr uInt8 signature[] = { 0x85, 0x3F };  // STA $3F
  return searchForBytes(image, size, signature, 2, 2);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbably4A50(const ByteBuffer& image, size_t size)
{
  // 4A50 carts store address $4A50 at the NMI vector, which
  // in this scheme is always in the last page of ROM at
  // $1FFA - $1FFB (at least this is true in rev 1 of the format)
  if(image[size-6] == 0x50 && image[size-5] == 0x4A)
    return true;

  // Program starts at $1Fxx with NOP $6Exx or NOP $6Fxx?
  if(((image[0xfffd] & 0x1f) == 0x1f) &&
      (image[image[0xfffd] * 256 + image[0xfffc]] == 0x0c) &&
      ((image[image[0xfffd] * 256 + image[0xfffc] + 2] & 0xfe) == 0x6e))
    return true;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbably4KSC(const ByteBuffer& image, size_t size)
{
  // We check if the first 256 bytes are identical *and* if there's
  // an "SC" signature for one of our larger SC types at 1FFA.
  const uInt8 first = image[0];
  for(uInt32 i = 1; i < 256; ++i)
    if(image[i] != first)
      return false;

  return (image[size-6] == 'S') && (image[size-5] == 'C');
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyBF(const ByteBuffer& image, size_t size,
                                Bankswitch::Type& type)
{
  // BF carts store strings 'BFBF' and 'BFSC' starting at address $FFF8
  // This signature is attributed to "RevEng" of AtariAge
  static constexpr uInt8 bf[]   = { 'B', 'F', 'B', 'F' };
  static constexpr uInt8 bfsc[] = { 'B', 'F', 'S', 'C' };
  if(searchForBytes(image.get()+size-8, 8, bf, 4))
  {
    type = Bankswitch::Type::_BF;
    return true;
  }
  else if(searchForBytes(image.get()+size-8, 8, bfsc, 4))
  {
    type = Bankswitch::Type::_BFSC;
    return true;
  }

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyBUS(const ByteBuffer& image, size_t size)
{
  // BUS ARM code has 2 occurrences of the string BUS
  // Note: all Harmony/Melody custom drivers also contain the value
  // 0x10adab1e (LOADABLE) if needed for future improvement
  static constexpr uInt8 bus[] = { 'B', 'U', 'S' };
  return searchForBytes(image, size, bus, 3, 2);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyCDF(const ByteBuffer& image, size_t size)
{
  // CDF ARM code has 3 occurrences of the string CDF
  // Note: all Harmony/Melody custom drivers also contain the value
  // 0x10adab1e (LOADABLE) if needed for future improvement
  static constexpr uInt8 cdf[] = { 'C', 'D', 'F' };
  static constexpr uInt8 cdfjplus[] = { 'P', 'L', 'U', 'S', 'C', 'D', 'F', 'J' };
  return (searchForBytes(image, size, cdf, 3, 3) ||
          searchForBytes(image, size, cdfjplus, 8, 1));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyCTY(const ByteBuffer& image, size_t size)
{
  static constexpr uInt8 lenin[] = { 'L', 'E', 'N', 'I', 'N' };
  return searchForBytes(image, size, lenin, 5);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyCV(const ByteBuffer& image, size_t size)
{
  // CV RAM access occurs at addresses $f3ff and $f400
  // These signatures are attributed to the MESS project
  static constexpr uInt8 signature[2][3] = {
    { 0x9D, 0xFF, 0xF3 },  // STA $F3FF,X  MagiCard
    { 0x99, 0x00, 0xF4 }   // STA $F400,Y  Video Life
  };
  if(searchForBytes(image, size, signature[0], 3))
    return true;
  else
    return searchForBytes(image, size, signature[1], 3);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyDF(const ByteBuffer& image, size_t size,
                                Bankswitch::Type& type)
{

  // DF carts store strings 'DFDF' and 'DFSC' starting at address $FFF8
  // This signature is attributed to "RevEng" of AtariAge
  static constexpr uInt8 df[]   = { 'D', 'F', 'D', 'F' };
  static constexpr uInt8 dfsc[] = { 'D', 'F', 'S', 'C' };
  if(searchForBytes(image.get()+size-8, 8, df, 4))
  {
    type = Bankswitch::Type::_DF;
    return true;
  }
  else if(searchForBytes(image.get()+size-8, 8, dfsc, 4))
  {
    type = Bankswitch::Type::_DFSC;
    return true;
  }

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyDPCplus(const ByteBuffer& image, size_t size)
{
  // DPC+ ARM code has 2 occurrences of the string DPC+
  // Note: all Harmony/Melody custom drivers also contain the value
  // 0x10adab1e (LOADABLE) if needed for future improvement
  static constexpr uInt8 dpcp[] = { 'D', 'P', 'C', '+' };
  return searchForBytes(image, size, dpcp, 4, 2);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyE0(const ByteBuffer& image, size_t size)
{
  // E0 cart bankswitching is triggered by accessing addresses
  // $FE0 to $FF9 using absolute non-indexed addressing
  // To eliminate false positives (and speed up processing), we
  // search for only certain known signatures
  // Thanks to "stella@casperkitty.com" for this advice
  // These signatures are attributed to the MESS project
  static constexpr uInt8 signature[8][3] = {
    { 0x8D, 0xE0, 0x1F },  // STA $1FE0
    { 0x8D, 0xE0, 0x5F },  // STA $5FE0
    { 0x8D, 0xE9, 0xFF },  // STA $FFE9
    { 0x0C, 0xE0, 0x1F },  // NOP $1FE0
    { 0xAD, 0xE0, 0x1F },  // LDA $1FE0
    { 0xAD, 0xE9, 0xFF },  // LDA $FFE9
    { 0xAD, 0xED, 0xFF },  // LDA $FFED
    { 0xAD, 0xF3, 0xBF }   // LDA $BFF3
  };
  for(const auto* const sig: signature)
    if(searchForBytes(image, size, sig, 3))
      return true;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyE7(const ByteBuffer& image, size_t size)
{
  // E7 cart bankswitching is triggered by accessing addresses
  // $FE0 to $FE6 using absolute non-indexed addressing
  // To eliminate false positives (and speed up processing), we
  // search for only certain known signatures
  // Thanks to "stella@casperkitty.com" for this advice
  // These signatures are attributed to the MESS project
  static constexpr uInt8 signature[7][3] = {
    { 0xAD, 0xE2, 0xFF },  // LDA $FFE2
    { 0xAD, 0xE5, 0xFF },  // LDA $FFE5
    { 0xAD, 0xE5, 0x1F },  // LDA $1FE5
    { 0xAD, 0xE7, 0x1F },  // LDA $1FE7
    { 0x0C, 0xE7, 0x1F },  // NOP $1FE7
    { 0x8D, 0xE7, 0xFF },  // STA $FFE7
    { 0x8D, 0xE7, 0x1F }   // STA $1FE7
  };
  for(const auto* const sig: signature)
    if(searchForBytes(image, size, sig, 3))
      return true;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyE78K(const ByteBuffer& image, size_t size)
{
  // E78K cart bankswitching is triggered by accessing addresses
  // $FE4 to $FE6 using absolute non-indexed addressing
  // To eliminate false positives (and speed up processing), we
  // search for only certain known signatures
  static constexpr uInt8 signature[3][3] = {
    { 0xAD, 0xE4, 0xFF },  // LDA $FFE4
    { 0xAD, 0xE5, 0xFF },  // LDA $FFE5
    { 0xAD, 0xE6, 0xFF },  // LDA $FFE6
  };
  for(const auto* const sig: signature)
    if(searchForBytes(image, size, sig, 3))
      return true;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyEF(const ByteBuffer& image, size_t size,
                                Bankswitch::Type& type)
{
  // Newer EF carts store strings 'EFEF' and 'EFSC' starting at address $FFF8
  // This signature is attributed to "RevEng" of AtariAge
  static constexpr uInt8 efef[] = { 'E', 'F', 'E', 'F' };
  static constexpr uInt8 efsc[] = { 'E', 'F', 'S', 'C' };
  if(searchForBytes(image.get()+size-8, 8, efef, 4))
  {
    type = Bankswitch::Type::_EF;
    return true;
  }
  else if(searchForBytes(image.get()+size-8, 8, efsc, 4))
  {
    type = Bankswitch::Type::_EFSC;
    return true;
  }

  // Otherwise, EF cart bankswitching switches banks by accessing addresses
  // 0xFE0 to 0xFEF, usually with either a NOP or LDA
  // It's likely that the code will switch to bank 0, so that's what is tested
  bool isEF = false;
  static constexpr uInt8 signature[4][3] = {
    { 0x0C, 0xE0, 0xFF },  // NOP $FFE0
    { 0xAD, 0xE0, 0xFF },  // LDA $FFE0
    { 0x0C, 0xE0, 0x1F },  // NOP $1FE0
    { 0xAD, 0xE0, 0x1F }   // LDA $1FE0
  };
  for(const auto* const sig: signature)
  {
    if(searchForBytes(image, size, sig, 3))
    {
      isEF = true;
      break;
    }
  }

  // Now that we know that the ROM is EF, we need to check if it's
  // the SC variant
  if(isEF)
  {
    type = isProbablySC(image, size) ? Bankswitch::Type::_EFSC : Bankswitch::Type::_EF;
    return true;
  }

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyFA2(const ByteBuffer& image, size_t)
{
  // This currently tests only the 32K version of FA2; the 24 and 28K
  // versions are easy, in that they're the only possibility with those
  // file sizes

  // 32K version has all zeros in 29K-32K area
  for(size_t i = 29_KB; i < 32_KB; ++i)
    if(image[i] != 0)
      return false;

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyFC(const ByteBuffer& image, size_t size)
{
  // FC bankswitching uses consecutive writes to 3 hotspots
  static constexpr uInt8 signature[3][6] = {
    { 0x8d, 0xf8, 0x1f, 0x4a, 0x4a, 0x8d }, // STA $1FF8, LSR, LSR, STA... Power Play Arcade Menus, 3-D Ghost Attack
    { 0x8d, 0xf8, 0xff, 0x8d, 0xfc, 0xff }, // STA $FFF8, STA $FFFC        Surf's Up (4K)
    { 0x8c, 0xf9, 0xff, 0xad, 0xfc, 0xff }  // STY $FFF9, LDA $FFFC        3-D Havoc
  };
  for(const auto* const sig: signature)
    if(searchForBytes(image, size, sig, 6))
      return true;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyFE(const ByteBuffer& image, size_t size)
{
  // FE bankswitching is very weird, but always seems to include a
  // 'JSR $xxxx'
  // These signatures are (mostly) attributed to the MESS project
  static constexpr uInt8 signature[5][5] = {
    { 0x20, 0x00, 0xD0, 0xC6, 0xC5 },  // JSR $D000; DEC $C5  Decathlon
    { 0x20, 0xC3, 0xF8, 0xA5, 0x82 },  // JSR $F8C3; LDA $82  Robot Tank
    { 0xD0, 0xFB, 0x20, 0x73, 0xFE },  // BNE $FB; JSR $FE73  Space Shuttle (NTSC/PAL)
    { 0xD0, 0xFB, 0x20, 0x68, 0xFE },  // BNE $FB; JSR $FE73  Space Shuttle (SECAM)
    { 0x20, 0x00, 0xF0, 0x84, 0xD6 }   // JSR $F000; $84, $D6 Thwocker
  };
  for(const auto* const sig: signature)
    if(searchForBytes(image, size, sig, 5))
      return true;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyGL(const ByteBuffer& image, size_t size)
{
  static constexpr uInt8 signature[] = { 0xad, 0xb8, 0x0c };  // LDA $0CB8

  return searchForBytes(image, size, signature, 3);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyMDM(const ByteBuffer& image, size_t size)
{
  // MDM cart is identified key 'MDMC' in the first 8K of ROM
  static constexpr uInt8 mdmc[] = { 'M', 'D', 'M', 'C' };
  return searchForBytes(image, std::min<size_t>(size, 8_KB), mdmc, 4);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyMVC(const ByteBuffer& image, size_t size)
{
  // MVC version 0
  static constexpr uInt8 sig[] = { 'M', 'V', 'C', 0 };
  constexpr int sigSize = sizeof(sig);
  return searchForBytes(image, std::min<size_t>(size, sigSize+1), sig, sigSize);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
size_t CartDetector::isProbablyMVC(const FSNode& rom)
{
  constexpr size_t frameSize = 2 * CartridgeMVC::MVC_FIELD_SIZE;

  if(Bankswitch::typeFromExtension(rom) == Bankswitch::Type::_MVC)
    return frameSize;

  Serializer s(rom.getPath(), Serializer::Mode::ReadOnly);
  if(s)
  {
    if(s.size() < frameSize)
      return 0;

    uInt8 image[frameSize];
    s.getByteArray(image, frameSize);

    static constexpr uInt8 sig[] = { 'M', 'V', 'C', 0 };  // MVC version 0
    return searchForBytes(image, frameSize, sig, 4) ? frameSize : 0;
  }
  return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablySB(const ByteBuffer& image, size_t size)
{
  // SB cart bankswitching switches banks by accessing address 0x0800
  static constexpr uInt8 signature[2][3] = {
    { 0xBD, 0x00, 0x08 },  // LDA $0800,x
    { 0xAD, 0x00, 0x08 }   // LDA $0800
  };
  if(searchForBytes(image, size, signature[0], 3))
    return true;
  else
    return searchForBytes(image, size, signature[1], 3);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyTVBoy(const ByteBuffer& image, size_t size)
{
  // TV Boy cart bankswitching switches banks by accessing addresses 0x1800..$187F
  static constexpr uInt8 signature[5] = { 0x91, 0x82, 0x6c, 0xfc, 0xff };  // STA ($82),Y; JMP ($FFFC)
  return searchForBytes(image, size, signature, 5);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyUA(const ByteBuffer& image, size_t size)
{
  // UA cart bankswitching switches to bank 1 by accessing address 0x240
  // using 'STA $240' or 'LDA $240'.
  // Brazilian (Digivison) cart bankswitching switches to bank 1 by accessing address 0x2C0
  // using 'BIT $2C0', 'STA $2C0' or 'LDA $2C0'
  static constexpr uInt8 signature[6][3] = {
    { 0x8D, 0x40, 0x02 },  // STA $240 (Funky Fish, Pleiades)
    { 0xAD, 0x40, 0x02 },  // LDA $240 (???)
    { 0xBD, 0x1F, 0x02 },  // LDA $21F,X (Gingerbread Man)
    { 0x2C, 0xC0, 0x02 },  // BIT $2C0 (Time Pilot)
    { 0x8D, 0xC0, 0x02 },  // STA $2C0 (Fathom, Vanguard)
    { 0xAD, 0xC0, 0x02 },  // LDA $2C0 (Mickey)
  };
  for(const auto* const sig: signature)
    if(searchForBytes(image, size, sig, 3))
      return true;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyWD(const ByteBuffer& image, size_t size)
{
  // WD cart bankswitching switches banks by accessing address 0x30..0x3f
  static constexpr uInt8 signature[1][3] = {
    { 0xA5, 0x39, 0x4C }  // LDA $39, JMP
  };
  return searchForBytes(image, size, signature[0], 3);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyX07(const ByteBuffer& image, size_t size)
{
  // X07 bankswitching switches to bank 0, 1, 2, etc by accessing address 0x08xd
  static constexpr uInt8 signature[6][3] = {
    { 0xAD, 0x0D, 0x08 },  // LDA $080D
    { 0xAD, 0x1D, 0x08 },  // LDA $081D
    { 0xAD, 0x2D, 0x08 },  // LDA $082D
    { 0x0C, 0x0D, 0x08 },  // NOP $080D
    { 0x0C, 0x1D, 0x08 },  // NOP $081D
    { 0x0C, 0x2D, 0x08 }   // NOP $082D
  };
  for(const auto* const sig: signature)
    if(searchForBytes(image, size, sig, 3))
      return true;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartDetector::isProbablyPlusROM(const ByteBuffer& image, size_t size)
{
  // PlusCart uses this pattern to detect a PlusROM
  static constexpr uInt8 signature[3] = { 0x8d, 0xf1, 0x1f };  // STA $1FF1

  return searchForBytes(image, size, signature, 3);
}
