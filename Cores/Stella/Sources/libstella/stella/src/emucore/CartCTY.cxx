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

#include "OSystem.hxx"
#include "Serializer.hxx"
#include "System.hxx"
#include "TimerManager.hxx"
#include "CartCTY.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CartridgeCTY::CartridgeCTY(const ByteBuffer& image, size_t size,
                           string_view md5, const Settings& settings)
  : Cartridge(settings, md5),
    myImage{make_unique<uInt8[]>(32_KB)}
{
  // Copy the ROM image into my buffer
  std::copy_n(image.get(), std::min(32_KB, size), myImage.get());
  createRomAccessArrays(32_KB);

  // Default to no tune data in case user is utilizing an old ROM
  myTuneData.fill(0);

  // Extract tune data if it exists
  if(size > 32_KB)
    std::copy_n(image.get() + 32_KB, size - 32_KB, myTuneData.begin());

  // Point to the first tune
  myFrequencyImage = myTuneData.data();

  myMusicCounters.fill(0);
  myMusicFrequencies.fill(0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCTY::reset()
{
  initializeRAM(myRAM.data(), myRAM.size());
  initializeStartBank(1);

  myRAM[0] = myRAM[1] = myRAM[2] = myRAM[3] = 0xFF;

  myLDAimmediate = false;
  myRandomNumber = 0x2B435044;
  myRamAccessTimeout = 0;

  myAudioCycles = 0;
  myFractionalClocks = 0.0;

  // Upon reset we switch to the startup bank
  bank(startBank());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCTY::consoleChanged(ConsoleTiming timing)
{
  constexpr double NTSC  = 1193191.66666667;  // NTSC  6507 clock rate
  constexpr double PAL   = 1182298.0;         // PAL   6507 clock rate
  constexpr double SECAM = 1187500.0;         // SECAM 6507 clock rate

  switch(timing)
  {
    case ConsoleTiming::ntsc:   myClockRate = NTSC;   break;
    case ConsoleTiming::pal:    myClockRate = PAL;    break;
    case ConsoleTiming::secam:  myClockRate = SECAM;  break;
    default:  break;  // satisfy compiler
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCTY::install(System& system)
{
  mySystem = &system;

  // Map all RAM accesses to call peek and poke
  const System::PageAccess access(this, System::PageAccessType::READ);
  for(uInt16 addr = 0x1000; addr < 0x1080; addr += System::PAGE_SIZE)
    mySystem->setPageAccess(addr, access);

  // Install pages for the startup bank
  bank(startBank());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeCTY::peek(uInt16 address)
{
  const uInt16 peekAddress = address;
  address &= 0x0FFF;
  const uInt8 peekValue = myImage[myBankOffset + address];

  // In debugger/bank-locked mode, we ignore all hotspots and in general
  // anything that can change the internal state of the cart
  if(hotspotsLocked())
    return peekValue;

  // Check for aliasing to 'LDA #$F2'
  if(myLDAimmediate && peekValue == 0xF2)
  {
    myLDAimmediate = false;

    // Update the music data fetchers (counter & flag)
    updateMusicModeDataFetchers();

    uInt8 i = 0;

    /*
     in the ARM driver registers 8-10 are the music counters 0-2
     lsr     r2, r8, #31
     add     r2, r2, r9, lsr #31
     add     r2, r2, r10, lsr #31
     lsl     r2, r2, #2
    */

    i = myMusicCounters[0] >> 31;
    i = i + (myMusicCounters[1] >> 31);
    i = i + (myMusicCounters[2] >> 31);
    i <<= 2;

    return i;

  }
  else
    myLDAimmediate = false;

  if(address < 0x0040)  // Write port is at $1000 - $103F (64 bytes)
  {
    // Reading from the write port triggers an unwanted write
    return peekRAM(myRAM[address], peekAddress);
  }
  else if(address < 0x0080)  // Read port is at $1040 - $107F (64 bytes)
  {
    address -= 0x40;
    switch(address)
    {
      case 0x00:  // Error code after operation
        return myRAM[0];
      case 0x01:  // Get next Random Number (8-bit LFSR)
        myRandomNumber = ((myRandomNumber & (1<<10)) ? 0x10adab1e: 0x00) ^
                         ((myRandomNumber >> 11) | (myRandomNumber << 21));
        return myRandomNumber & 0xFF;
      case 0x02:  // Get Tune position (low byte)
        return myTunePosition & 0xFF;
      case 0x03:  // Get Tune position (high byte)
        return (myTunePosition >> 8) & 0xFF;
      default:
        return myRAM[address];
    }
  }
  else  // Check hotspots
  {
    switch(address)
    {
      case 0x0FF4:
        // Bank 0 is ARM code and not actually accessed
        return ramReadWrite();
      case 0x0FF5:
      case 0x0FF6:
      case 0x0FF7:
      case 0x0FF8:
      case 0x0FF9:
      case 0x0FFA:
      case 0x0FFB:
        // Banks 1 through 7
        bank(address - 0x0FF4);
        break;
      default:
        break;
    }

    // Is this instruction an immediate mode LDA?
    myLDAimmediate = (peekValue == 0xA9);

    return peekValue;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeCTY::poke(uInt16 address, uInt8 value)
{
  const uInt16 pokeAddress = address;
  address &= 0x0FFF;

  if(address < 0x0040)  // Write port is at $1000 - $103F (64 bytes)
  {
    switch(address)
    {
      case 0x00:  // Operation type for $1FF4
        myOperationType = value;
        break;
      case 0x01:  // Set Random seed value (reset)
        myRandomNumber = 0x2B435044;
        break;
      case 0x02:  // Reset fetcher to beginning of tune
        myTunePosition = 0;
        myMusicCounters[0] = 0;
        myMusicCounters[1] = 0;
        myMusicCounters[2] = 0;
        myMusicFrequencies[0] = 0;
        myMusicFrequencies[1] = 0;
        myMusicFrequencies[2] = 0;
        break;
      case 0x03:  // Advance fetcher to next tune position
        updateTune();
        break;
      default:
        pokeRAM(myRAM[address], pokeAddress, value);
        break;
    }
  }
  else  // Check hotspots
  {
    switch(address)
    {
      case 0x0FF4:
        // Bank 0 is ARM code and not actually accessed
        ramReadWrite();
        break;
      case 0x0FF5:
      case 0x0FF6:
      case 0x0FF7:
      case 0x0FF8:
      case 0x0FF9:
      case 0x0FFA:
      case 0x0FFB:
        // Banks 1 through 7
        bank(address - 0x0FF4);
        break;
      default:
        break;
    }
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeCTY::bank(uInt16 bank, uInt16)
{
  if(hotspotsLocked()) return false;

  // Remember what bank we're in
  myBankOffset = bank << 12;

  // Setup the page access methods for the current bank
  System::PageAccess access(this, System::PageAccessType::READ);
  for(uInt16 addr = 0x1080; addr < 0x2000; addr += System::PAGE_SIZE)
  {
    access.romAccessBase = &myRomAccessBase[myBankOffset + (addr & 0x0FFF)];
    access.romPeekCounter = &myRomAccessCounter[myBankOffset + (addr & 0x0FFF)];
    access.romPokeCounter = &myRomAccessCounter[myBankOffset + (addr & 0x0FFF) + myAccessSize];
    mySystem->setPageAccess(addr, access);
  }
  return myBankChanged = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 CartridgeCTY::getBank(uInt16) const
{
  return myBankOffset >> 12;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt16 CartridgeCTY::romBankCount() const
{
  return 8;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeCTY::patch(uInt16 address, uInt8 value)
{
  address &= 0x0FFF;

  if(address < 0x0080)
  {
    // Normally, a write to the read port won't do anything
    // However, the patch command is special in that ignores such
    // cart restrictions
    myRAM[address & 0x003F] = value;
  }
  else
    myImage[myBankOffset + address] = value;

  return myBankChanged = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const ByteBuffer& CartridgeCTY::getImage(size_t& size) const
{
  size = 32_KB;
  return myImage;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeCTY::save(Serializer& out) const
{
  try
  {
    out.putShort(getBank());
    out.putByteArray(myRAM.data(), myRAM.size());

    out.putByte(myOperationType);
    out.putShort(myTunePosition);
    out.putBool(myLDAimmediate);
    out.putInt(myRandomNumber);
    out.putLong(myAudioCycles);
    out.putDouble(myFractionalClocks);
    out.putIntArray(myMusicCounters.data(), myMusicCounters.size());
    out.putIntArray(myMusicFrequencies.data(), myMusicFrequencies.size());
    out.putLong(myFrequencyImage - myTuneData.data()); // FIXME - storing pointer diff!
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeCTY::save\n";
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool CartridgeCTY::load(Serializer& in)
{
  try
  {
    // Remember what bank we were in
    bank(in.getShort());
    in.getByteArray(myRAM.data(), myRAM.size());

    myOperationType = in.getByte();
    myTunePosition = in.getShort();
    myLDAimmediate = in.getBool();
    myRandomNumber = in.getInt();
    myAudioCycles = in.getLong();
    myFractionalClocks = in.getDouble();
    in.getIntArray(myMusicCounters.data(), myMusicCounters.size());
    in.getIntArray(myMusicFrequencies.data(), myMusicFrequencies.size());
    myFrequencyImage = myTuneData.data() + in.getLong();
  }
  catch(...)
  {
    cerr << "ERROR: CartridgeCTY::load\n";
    return false;
  }
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCTY::setNVRamFile(string_view path)
{
  myEEPROMFile = string{path} + "_eeprom.dat";
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 CartridgeCTY::ramReadWrite()
{
  /* The following algorithm implements accessing Harmony cart EEPROM

    1. Wait for an access to hotspot location $1FF4 (return 1 in bit 6
       while busy).

    2. Determine operation from myOperationType.

    3. Save or load relevant EEPROM memory to/from a file.

    4. Set byte 0 of RAM+ memory to zero to indicate success (will
       always happen in emulation).

    5. Return 0 (in bit 6) on the next access to $1FF4, if enough time has
       passed to complete the operation on a real system (0.5 s for read,
       1 s for write).
  */

  if(hotspotsLocked()) return 0xff;

  // First access sets the timer
  if(myRamAccessTimeout == 0)
  {
    // Opcode and value in form of XXXXYYYY (from myOperationType), where:
    //    XXXX = index and YYYY = operation
    const uInt8 index = myOperationType >> 4;
    switch(myOperationType & 0xf)
    {
      case 1:  // Load tune (index = tune)
        if(index < 7)
        {
          // Add 0.5 s delay for read
          myRamAccessTimeout = TimerManager::getTicks() + 500000;
          loadTune(index);
        }
        break;
      case 2:  // Load score table (index = table)
        if(index < 4)
        {
          // Add 0.5 s delay for read
          myRamAccessTimeout = TimerManager::getTicks() + 500000;
          loadScore(index);
        }
        break;
      case 3:  // Save score table (index = table)
        if(index < 4)
        {
          // Add 1 s delay for write
          myRamAccessTimeout = TimerManager::getTicks() + 1000000;
          saveScore(index);
        }
        break;
      case 4:  // Wipe all score tables
        // Add 1 s delay for write
        myRamAccessTimeout = TimerManager::getTicks() + 1000000;
        wipeAllScores();
        break;

      default:  // satisfy compiler
        break;
    }
    // Bit 6 is 1, busy
    return myImage[myBankOffset + 0xFF4] | 0x40;
  }
  else
  {
    // Have we reached the timeout value yet?
    if(TimerManager::getTicks() >= myRamAccessTimeout)
    {
      myRamAccessTimeout = 0;  // Turn off timer
      myRAM[0] = 0;            // Successful operation

      // Bit 6 is 0, ready/success
      return myImage[myBankOffset + 0xFF4] & ~0x40;
    }
    else
      // Bit 6 is 1, busy
      return myImage[myBankOffset + 0xFF4] | 0x40;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCTY::loadTune(uInt8 index)
{
  // Each tune is offset by 4096 bytes
  // Instead of copying non-modifiable data around (as would happen on the
  // Harmony), we simply point to the appropriate tune
  myFrequencyImage = myTuneData.data() + (index << 12);

  // Reset to beginning of tune
  myTunePosition = 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCTY::updateTune()
{
//UpdateTune:
//  /* Float data bus */
//  strb    r8, [r0, #+0x01]
//
//  /* Increment song position */
//  add     r7, r7, #1                r7 = songPosition
//
//  /* Read song data (0 = continue) */
//  msr     cpsr_c, #MODE_FIQ|I_BIT|F_BIT
//  ldrb    r2, [r14], #1             r14 = myTunePosition, r2 = note
//  cmp     r2, #0
//  ldrne   r11, [r6, +r2, lsl #2]    r6 +r2 = ourFrequencyTable[note].  Why lsl #2?
//  ldrb    r2, [r14], #1             r11 = myMusicFrequency[0]
//  cmp     r2, #0
//  ldrne   r12, [r6, +r2, lsl #2]    r12 = myMusicFrequency[1]
//  ldrb    r2, [r14], #1
//  cmp     r2, #1
//  ldrcs   r13, [r6, +r2, lsl #2]    r13 = myMusicFrequency[2]
//
//  /* Reset tune */
//  mvneq   r7, #0
//  moveq   r14, r4                   r4 = start of tune data
//  msr     cpsr_c, #MODE_SYS|I_BIT|F_BIT
//
//  /* Wait until address changes */
//WaitAddrChangeA:
//  ldrh    r2, [r0, #+0x16]
//  cmp     r1, r2
//  beq     WaitAddrChangeA
//  b       NewAddress

  myTunePosition += 1;
  const uInt16 songPosition = (myTunePosition - 1) *3;

  uInt8 note = myFrequencyImage[songPosition + 0];
  if (note)
    myMusicFrequencies[0] = ourFrequencyTable[note];

  note = myFrequencyImage[songPosition + 1];
  if (note)
    myMusicFrequencies[1] = ourFrequencyTable[note];

  note = myFrequencyImage[songPosition + 2];
  if (note == 1)
    myTunePosition = 0;
  else
    myMusicFrequencies[2] = ourFrequencyTable[note];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCTY::loadScore(uInt8 index)
{
  const Serializer serializer(myEEPROMFile, Serializer::Mode::ReadOnly);
  if(serializer)
  {
    std::array<uInt8, 256> scoreRAM;
    try
    {
      serializer.getByteArray(scoreRAM.data(), scoreRAM.size());
    }
    catch(...)
    {
      scoreRAM.fill(0);
    }

    // Grab 60B slice @ given index (first 4 bytes are ignored)
    std::copy_n(scoreRAM.begin() + (index << 6) + 4, 60, myRAM.begin() + 4);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCTY::saveScore(uInt8 index)
{
  Serializer serializer(myEEPROMFile);
  if(serializer)
  {
    // Load score RAM
    std::array<uInt8, 256> scoreRAM;
    try
    {
      serializer.getByteArray(scoreRAM.data(), scoreRAM.size());
    }
    catch(...)
    {
      scoreRAM.fill(0);
    }

    // Add 60B RAM to score table @ given index (first 4 bytes are ignored)
    std::copy_n(myRAM.begin() + 4, 60, scoreRAM.begin() + (index << 6) + 4);

    // Save score RAM
    serializer.rewind();
    try
    {
      serializer.putByteArray(scoreRAM.data(), scoreRAM.size());
    }
    catch(...)
    {
      // Maybe add logging here that save failed?
      cerr << name() << ": ERROR saving score table " << static_cast<int>(index) << '\n';
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void CartridgeCTY::wipeAllScores()
{
  Serializer serializer(myEEPROMFile);
  if(serializer)
  {
    // Erase score RAM
    std::array<uInt8, 256> scoreRAM = {};
    try
    {
      serializer.putByteArray(scoreRAM.data(), scoreRAM.size());
    }
    catch(...)
    {
      // Maybe add logging here that save failed?
      cerr << name() << ": ERROR wiping score tables\n";
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FORCE_INLINE void CartridgeCTY::updateMusicModeDataFetchers()
{
  // Calculate the number of cycles since the last update
  const auto cycles = static_cast<uInt32>(mySystem->cycles() - myAudioCycles);
  myAudioCycles = mySystem->cycles();

  // Calculate the number of CTY OSC clocks since the last update
  const double clocks = ((20000.0 * cycles) / myClockRate) + myFractionalClocks;
  const auto wholeClocks = static_cast<uInt32>(clocks);
  myFractionalClocks = clocks - static_cast<double>(wholeClocks);

  // Let's update counters and flags of the music mode data fetchers
  if(wholeClocks > 0)
    for(int x = 0; x <= 2; ++x)
      myMusicCounters[x] += myMusicFrequencies[x] * wholeClocks;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const std::array<uInt32, 63> CartridgeCTY::ourFrequencyTable =
{
  // this should really be referenced from within the ROM, but its part of
  // the Harmony/Melody CTY Driver, which does not appear to be in the ROM.

     0,           // CONT   0   Continue Note
     0,           // REPEAT 1   Repeat Song
     0,           // REST   2   Note Rest
  /*
      3511350     // C0
      3720300     // C0s
      3941491     // D0
      4175781     // D0s
      4424031     // E0
      4687313     // F0
      4965841     // F0s
      5261120     // G0
      5496699     // G0s

      5905580     // A1
      6256694     // A1s
      6628853     // B1
      7022916     // C1
      7440601     // C1s
      7882983     // D1
      8351778     // D1s
      8848277     // E1
      9374625     // F1
      9931897     // F1s
      10522455    // G1
      11148232    // G1s
   */
     11811160,    // A2
     12513387,    // A2s
     13257490,    // B2
     14045832,    // C2
     14881203,    // C2s
     15765966,    // D2
     16703557,    // D2s
     17696768,    // E2
     18749035,    // F2
     19864009,    // F2s
     21045125,    // G2
     22296464,    // G2s

     23622320,    // A3
     25026989,    // A3s
     26515195,    // B3
     28091878,    // C3
     29762191,    // C3s
     31531932,    // D3
     33406900,    // D3s
     35393537,    // E3
     37498071,    // F3
     39727803,    // F3s
     42090250,    // G3
     44592927,    // G3s

     47244640,    // A4
     50053978,    // A4s
     53030391,    // B4
     56183756,    // C4   (Middle C)
     59524596,    // C4s
     63064079,    // D4
     66814014,    // D4s
     70787074,    // E4
     74996142,    // F4
     79455606,    // F4s
     84180285,    // G4
     89186069,    // G4s

     94489281,    // A5
     100107957,   // A5s
     106060567,   // B5
     112367297,   // C5
     119048977,   // C5s
     126128157,   // D5
     133628029,   // D5s
     141573933,   // E5
     149992288,   // F5
     158911428,   // F5s
     168360785,   // G5
     178371925,   // G5s

     188978561,   // A6
     200215913,   // A6s
     212121348,   // B6
     224734593,   // C6
     238098169,   // C6s
     252256099,   // D6
     267256058,   // D6s
     283147866,   // E6
     299984783,   // F6
     317822855,   // F6s
     336721571,   // G6
     356744064   // G6s
  /*
      377957122   // A7
      400431612   // A7s
      424242481   // B7
      449469401   // C7
      476196124   // C7s
      504512198   // D7
      534512116   // D7s
      566295948   // E7
      599969565   // F7
      635645496   // F7s
      673443141   // G7
      713488128   // G7s

      755914244   // A8
      800863224   // A8s
      848484963   // B8
      898938588   // C8
      952392248   // C8s
      1009024398  // D8
      1069024232  // D8s
      1132591895  // E8
      1199939130  // F8
      1271290992  // F8s
      1346886282  // G8
      1426976255  // G8s

      1511828488  // A9
      1601726449  // A9s
      1696969925  // B9
      1797877176  // C9
      1904784495  // C9s
      2018048796  // D9
      2138048463  // D9s
  */
};
