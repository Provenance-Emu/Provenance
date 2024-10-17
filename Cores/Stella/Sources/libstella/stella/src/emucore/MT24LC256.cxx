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

#include "System.hxx"
#include "MT24LC256.hxx"

//#define DEBUG_EEPROM

#ifdef DEBUG_EEPROM
  static char jpee_msg[256];
  #define JPEE_LOG0(msg) jpee_logproc(msg);
  #define JPEE_LOG1(msg,arg1) sprintf(jpee_msg,(msg),(arg1)), jpee_logproc(jpee_msg);
  #define JPEE_LOG2(msg,arg1,arg2) sprintf(jpee_msg,(msg),(arg1),(arg2)), jpee_logproc(jpee_msg);
#else
  #define JPEE_LOG0(msg)
  #define JPEE_LOG1(msg,arg1)
  #define JPEE_LOG2(msg,arg1,arg2)
#endif

/*
  State values for I2C:
    0 - Idle
    1 - Byte going to chip (shift left until bit 8 is set)
    2 - Chip outputting acknowledgement
    3 - Byte coming in from chip (shift left until lower 8 bits are clear)
    4 - Chip waiting for acknowledgement
*/

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
MT24LC256::MT24LC256(const FSNode& eepromfile, const System& system,
                     const Controller::onMessageCallback& callback)
  : mySystem{system},
    myCallback{callback},
    myDataFile{eepromfile}
{
  // Load the data from an external file (if it exists)
  bool fileValid = false;
  try
  {
    // A valid file must be 32768 bytes; otherwise we create a new one
    if(myDataFile.read(myData) == FLASH_SIZE)
      fileValid = true;
  }
  catch(...)
  {
    fileValid = false;
  }

  if(!fileValid)
  {
    myData = make_unique<uInt8[]>(FLASH_SIZE);
    std::fill_n(myData.get(), FLASH_SIZE, INITIAL_VALUE);
    myDataChanged = true;
   }

  // Then initialize the I2C state
  jpee_init();

  systemReset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
MT24LC256::~MT24LC256()
{
  // Save EEPROM data to external file only when necessary
  if(myDataChanged)
  {
    try { myDataFile.write(myData, FLASH_SIZE); }
    catch(...) { cerr << "ERROR writing MT24LC256 data file\n"; }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MT24LC256::writeSDA(bool state)
{
  mySDA = state;
  myCyclesWhenSDASet = mySystem.cycles();

  update();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MT24LC256::writeSCL(bool state)
{
  mySCL = state;
  myCyclesWhenSCLSet = mySystem.cycles();

  update();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MT24LC256::update()
{
#define jpee_clock(x) ( (x) ? \
  (jpee_mclk = 1) : \
  (jpee_mclk && (jpee_clock_fall(),1), jpee_mclk = 0))

#define jpee_data(x) ( (x) ? \
  (!jpee_mdat && jpee_sdat && jpee_mclk && (jpee_data_stop(),1), jpee_mdat = 1) : \
  (jpee_mdat && jpee_sdat && jpee_mclk && (jpee_data_start(),1), jpee_mdat = 0))

  // These pins have to be updated at the same time
  // However, there's no guarantee that the writeSDA() and writeSCL()
  // methods will be called at the same time or in the correct order, so
  // we only do the write when they have the same 'timestamp'
  if(myCyclesWhenSDASet == myCyclesWhenSCLSet)
  {
#ifdef DEBUG_EEPROM
    cerr << "\n  I2C_PIN_WRITE(SCL = " << mySCL
         << ", SDA = " << mySDA << ")" << " @ " << mySystem.cycles() << '\n';
#endif
    jpee_clock(mySCL);
    jpee_data(mySDA);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MT24LC256::systemReset()
{
  myPageHit.fill(false);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MT24LC256::eraseAll()
{
  std::fill_n(myData.get(), FLASH_SIZE, INITIAL_VALUE);
  myDataChanged = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MT24LC256::eraseCurrent()
{
  for(uInt32 page = 0; page < PAGE_NUM; ++page)
  {
    if(myPageHit[page])
    {
      std::fill_n(myData.get() + page * PAGE_SIZE, PAGE_SIZE, INITIAL_VALUE);
      myDataChanged = true;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool MT24LC256::isPageUsed(uInt32 page) const
{
  if(page < PAGE_NUM)
    return myPageHit[page];
  else
    return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MT24LC256::jpee_init()
{
  jpee_sdat = 1;
  jpee_address = 0;
  jpee_state=0;
  jpee_sizemask = FLASH_SIZE - 1;
  jpee_pagemask = PAGE_SIZE - 1;
  jpee_smallmode = 0;
  jpee_logmode = -1;
  jpee_packet.fill(0);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MT24LC256::jpee_data_start()
{
  /* We have a start condition */
  if (jpee_state == 1 && (jpee_nb != 1 || jpee_pptr != 3))
  {
    JPEE_LOG0("I2C_WARNING ABANDON WRITE")
    jpee_ad_known = 0;
  }
  if (jpee_state == 3)
  {
    JPEE_LOG0("I2C_WARNING ABANDON READ")
  }
  if (!jpee_timercheck(0))
  {
    JPEE_LOG0("I2C_START")
    jpee_state = 2;
  }
  else
  {
    JPEE_LOG0("I2C_BUSY")
    jpee_state = 0;
  }
  jpee_pptr = 0;
  jpee_nb = 0;
  jpee_packet[0] = 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MT24LC256::jpee_data_stop()
{
  if (jpee_state == 1 && jpee_nb != 1)
  {
    JPEE_LOG0("I2C_WARNING ABANDON_WRITE")
    jpee_ad_known = 0;
  }
  if (jpee_state == 3)
  {
    JPEE_LOG0("I2C_WARNING ABANDON_READ")
    jpee_ad_known = 0;
  }
  /* We have a stop condition. */
  if (jpee_state == 1 && jpee_nb == 1 && jpee_pptr > 3)
  {
    jpee_timercheck(1);
    JPEE_LOG2("I2C_STOP(Write %d bytes at %04X)",jpee_pptr-3,jpee_address)
    if (((jpee_address + jpee_pptr-4) ^ jpee_address) & ~jpee_pagemask)
    {
      jpee_pptr = 4+jpee_pagemask-(jpee_address & jpee_pagemask);
      JPEE_LOG1("I2C_WARNING PAGECROSSING!(Truncate to %d bytes)",jpee_pptr-3)
    }
    for (int i=3; i<jpee_pptr; i++)
    {
      myDataChanged = true;
      myPageHit[jpee_address / PAGE_SIZE] = true;

      myCallback("AtariVox/SaveKey EEPROM write");

      myData[(jpee_address++) & jpee_sizemask] = jpee_packet[i];
      if (!(jpee_address & jpee_pagemask))
        break;  /* Writes can't cross page boundary! */
    }
    jpee_ad_known = 0;
  }
#ifdef DEBUG_EEPROM
  else
    jpee_logproc("I2C_STOP");
#endif

  jpee_state = 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void MT24LC256::jpee_clock_fall()
{
  switch(jpee_state)
  {
    case 1:
      jpee_nb <<= 1;
      jpee_nb |= jpee_mdat;
      if (jpee_nb & 256)
      {
        if (!jpee_pptr)
        {
          jpee_packet[0] = static_cast<uInt8>(jpee_nb);
          if (jpee_smallmode && ((jpee_nb & 0xF0) == 0xA0))
          {
            jpee_packet[1] = (jpee_nb >> 1) & 7;
          #ifdef DEBUG_EEPROM
            if (jpee_packet[1] != (jpee_address >> 8) && (jpee_packet[0] & 1))
              jpee_logproc("I2C_WARNING ADDRESS MSB CHANGED");
          #endif
            jpee_nb &= 0x1A1;
          }
          if (jpee_nb == 0x1A0)
          {
            JPEE_LOG1("I2C_SENT(%02X--start write)",jpee_packet[0])
            jpee_state = 2;
            jpee_sdat = 0;
          }
          else if (jpee_nb == 0x1A1)
          {
            jpee_state = 4;
            JPEE_LOG2("I2C_SENT(%02X--start read @%04X)", jpee_packet[0],jpee_address)
          #ifdef DEBUG_EEPROM
            if (!jpee_ad_known)
              jpee_logproc("I2C_WARNING ADDRESS IS UNKNOWN");
          #endif
            jpee_sdat = 0;
          }
          else
          {
            JPEE_LOG1("I2C_WARNING ODDBALL FIRST BYTE!(%02X)",jpee_nb & 0xFF)
            jpee_state = 0;
          }
        }
        else
        {
          jpee_state = 2;
          jpee_sdat = 0;
        }
      }
      break;

    case 2:
      if (jpee_nb)
      {
        if (!jpee_pptr)
        {
          jpee_packet[0] = static_cast<uInt8>(jpee_nb);
          if (jpee_smallmode)
            jpee_pptr=2;
          else
            jpee_pptr=1;
        }
        else if (jpee_pptr < 70)
        {
          JPEE_LOG1("I2C_SENT(%02X)",jpee_nb & 0xFF)
          jpee_packet[jpee_pptr++] = static_cast<uInt8>(jpee_nb);
          jpee_address = (jpee_packet[1] << 8) | jpee_packet[2];
          if (jpee_pptr > 2)
            jpee_ad_known = 1;
        }
      #ifdef DEBUG_EEPROM
        else
          jpee_logproc("I2C_WARNING OUTPUT_OVERFLOW!");
      #endif
      }
      jpee_sdat = 1;
      jpee_nb = 1;
      jpee_state=1;
      break;

    case 4:
      if (jpee_mdat && jpee_sdat)
      {
        JPEE_LOG0("I2C_READ_NAK")
        jpee_state=0;
        break;
      }
      jpee_state=3;
      myPageHit[jpee_address / PAGE_SIZE] = true;

      myCallback("AtariVox/SaveKey EEPROM read");

      jpee_nb = (myData[jpee_address & jpee_sizemask] << 1) | 1;  /* Fall through */
      JPEE_LOG2("I2C_READ(%04X=%02X)",jpee_address,jpee_nb/2)
      [[fallthrough]];

    case 3:
      jpee_sdat = !!(jpee_nb & 256);
      jpee_nb <<= 1;
      if (!(jpee_nb & 510))
      {
        jpee_state = 4;
        jpee_sdat = 1;
        ++jpee_address;
      }
      break;

    default:
      /* Do nothing */
      break;
  }
  JPEE_LOG2("I2C_CLOCK (dat=%d/%d)",jpee_mdat,jpee_sdat)
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool MT24LC256::jpee_timercheck(int mode)
{
  /*
    Evaluate how long the EEPROM is busy.  When invoked with an argument of 1,
    start a timer (probably about 5 milliseconds); when invoked with an
    argument of 0, return zero if the timer has expired or non-zero if it is
    still running.
  */
  if(mode)  // set timer
  {
    myCyclesWhenTimerSet = mySystem.cycles();
    return myTimerActive = true;
  }
  else      // read timer
  {
    if(myTimerActive)
    {
      const uInt64 elapsed = mySystem.cycles() - myCyclesWhenTimerSet;
      myTimerActive = elapsed < static_cast<uInt64>(5000000.0 / 838.0);
    }
    return myTimerActive;
  }
}
