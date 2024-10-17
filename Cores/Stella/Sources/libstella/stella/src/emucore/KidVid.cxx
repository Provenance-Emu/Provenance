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

#include "Console.hxx"
#include "Event.hxx"
#include "FSNode.hxx"
#include "OSystem.hxx"
#include "Sound.hxx"
#include "Switches.hxx"

#include "KidVid.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
KidVid::KidVid(Jack jack, const Event& event, const OSystem& osystem,
               const System& system, string_view romMd5,
               const onMessageCallbackForced& callback)
  : Controller(jack, event, system, Controller::Type::KidVid),
    myEnabled{myJack == Jack::Right},
    myOSystem{osystem},
    myCallback{callback}
{
  // Right now, there are only two games that use the KidVid
  if(romMd5 == "ee6665683ebdb539e89ba620981cb0f6")
    myGame = Game::BBears;    // Berenstain Bears
  else if(romMd5 == "a204cd4fb1944c86e800120706512a64")
    myGame = Game::Smurfs;    // Smurfs Save the Day
  else
    myEnabled = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void KidVid::write(DigitalPin pin, bool value)
{
  // Change the pin state based on value
  switch(pin)
  {
    // Pin 1: Signal tape running or stopped
    case DigitalPin::One:
      setPin(DigitalPin::One, value);
      break;

    default:
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void KidVid::update()
{
  if(!myEnabled)
    return;

  if(myContinueSong)
  {
    // Continue playing song after state load
    const uInt8 temp = ourSongPositions[mySongPointer - 1] & 0x7f;
    const uInt32 songLength = ourSongStart[temp + 1] - ourSongStart[temp] - (262 * ClickFrames);

    // Play the remaining WAV file
    const string& fileName = myOSystem.baseDir().getPath() +
      ((temp < 10) ? "KVSHARED.WAV": getFileName());
    myOSystem.sound().playWav(fileName, ourSongStart[temp] + (songLength - mySongLength), mySongLength);

    myContinueSong = false;
  }

  if(myGame == Game::Smurfs && myEvent.get(Event::ConsoleReset)) // Reset does not work with BBears!
  {
    myTape = 0; // rewind Kid Vid tape
    myFilesFound = mySongPlaying = false;
    myOSystem.sound().stopWav();
  }
  else if(myEvent.get(Event::RightKeyboard6) || myEvent.get(Event::ConsoleSelect) ||
          (myOSystem.hasConsole() && !myOSystem.console().switches().tvColor()))
  {
    // Some first songs trigger a sequence of timed actions, they cannot be skipped
    if(mySongPointer &&
        ourSongPositions[mySongPointer - 1] != 0 && // First song of all BBears games
        ourSongPositions[mySongPointer - 1] != 11)  // First song of Harmony Smurf
      myOSystem.sound().stopWav();
  }
  if(!myTape)
  {
    if(myEvent.get(Event::RightKeyboard1))
      myTape = 2;
    else if(myEvent.get(Event::RightKeyboard2))
      myTape = 3;
    else if(myEvent.get(Event::RightKeyboard3))
      myTape = myGame == Game::BBears ? 4 : 1; // Berenstain Bears or Smurfs Save The Day?
    // If no Keyboard controller is available, use SELECT and the same
    // switches settings as for playing Smurfs without a Kid Vid.
    else if(myEvent.get(Event::ConsoleSelect) && myOSystem.hasConsole())
    {
      // Harmony (2) : A B
      // Handy (3)   : B A
      // Greedy (1/4): B B
      myTape = 1
        + (myOSystem.console().switches().leftDifficultyA() ? 1 : 0)
        + (myOSystem.console().switches().rightDifficultyA() ? 2 : 0);
      if(myTape == 4) // ignore A A
        myTape = 0;
      else if(myTape == 1 && myGame == Game::BBears)
        myTape = 4;
    }
    if(myTape)
    {
      static constexpr uInt32 gameNumber[4] = { 3, 1, 2, 3 };
      static constexpr string_view gameName[6] = {
        "Harmony Smurf", "Handy Smurf", "Greedy Smurf",
        "Big Number Hunt", "Great Letter Roundup", "Spooky Spelling Bee"
      };

      myIdx = myGame == Game::BBears ? NumBlockBits : 0; // KVData48/KVData44
      myBlockIdx = NumBlockBits;
      myBlock = 0;
      openSampleFiles();

      ostringstream msg;
      msg << "Game #" << gameNumber[myTape - 1] << " - \""
        << gameName[gameNumber[myTape - 1] + (myGame == Game::Smurfs ? -1 : 2)] << "\"";
      myCallback(msg.str(), true);
    }
  }

  // Is the tape running?
  if(myTape && getPin(DigitalPin::One) && !myTapeBusy)
  {
    setPin(DigitalPin::Four, (ourData[myIdx >> 3] << (myIdx & 0x07)) & 0x80);

  #ifdef DEBUG_BUILD
    cerr << (DigitalPin::Four, (ourData[myIdx >> 3] << (myIdx & 0x07)) & 0x80 ? "X" : ".");
  #endif

    // increase to next bit
    ++myIdx;
    --myBlockIdx;

    // increase to next block (byte)
    if(!myBlockIdx)
    {
      if(!myBlock)
        myIdx = ((myTape * 6) + 12 - NumBlocks) * 8; // KVData00 - ourData = 12 (2 * 6)
      else
      {
        const uInt32 lastBlock = myGame == Game::Smurfs
          ? ourBlocks[myTape - 1]
          : ourBlocks[myTape + 2 - 1];
        if(myBlock >= lastBlock)
          myIdx = 42 * 8; // KVData80 - ourData = 42 (7 * 6)
        else
        {
          myIdx = 36 * 8; // KVPause - ourData = 36 (6 * 6)
          setNextSong();
        }
      }
      ++myBlock;
      myBlockIdx = NumBlockBits;
    }
  }

  if(myFilesFound)
  {
    if(mySongPlaying)
    {
      mySongLength = myOSystem.sound().wavSize();
      myTapeBusy = (mySongLength > 262 * TapeFrames) || !myBeep;
      // Check for end of played sample
      if(mySongLength == 0)
      {
        mySongPlaying = false;
        myTapeBusy = !myBeep;
        if(!myBeep)
          setNextSong();
      }
    }
  }
  else
  {
    if(mySongLength)
    {
      --mySongLength;
      myTapeBusy = (mySongLength > TapeFrames);
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool KidVid::save(Serializer& out) const
{
  // Save WAV player state
  out.putInt(myTape);
  out.putBool(myFilesFound);
  out.putBool(myTapeBusy);
  out.putBool(myBeep);
  out.putBool(mySongPlaying);
  out.putInt(mySongPointer);
  out.putInt(mySongLength);
  // Save tape input simulation state
  out.putInt(myIdx);
  out.putInt(myBlockIdx);
  out.putInt(myBlock);

  return Controller::save(out);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool KidVid::load(Serializer& in)
{
  // Load WAV player state
  myTape = in.getInt();
  myFilesFound = in.getBool();
  myTapeBusy = in.getBool();
  myBeep = in.getBool();
  mySongPlaying = in.getBool();
  mySongPointer = in.getInt();
  mySongLength = in.getInt();
  // Load tape input simulation state
  myIdx = in.getInt();
  myBlockIdx = in.getInt();
  myBlock = in.getInt();

  myContinueSong = myFilesFound && mySongPlaying;

  return Controller::load(in);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const char* KidVid::getFileName() const
{
  static constexpr const char* const fileNames[6] = {
    "KVS3.WAV", "KVS1.WAV", "KVS2.WAV",
    "KVB3.WAV", "KVB1.WAV", "KVB2.WAV"
  };

  int i = myGame == Game::Smurfs ? myTape - 1 : myTape + 2;
  if(myTape == 4) i = 3;

  return fileNames[i];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void KidVid::openSampleFiles()
{
#ifdef SOUND_SUPPORT
  static constexpr uInt32 firstSongPointer[6] = {
    44 + 38,
    0,
    44,
    44 + 38 + 42 + 62 + 80,
    44 + 38 + 42,
    44 + 38 + 42 + 62
  };

  if(!myFilesFound)
  {
    int i = myGame == Game::Smurfs ? myTape - 1 : myTape + 2;
    if(myTape == 4) i = 3;

    myFilesFound = FSNode(myOSystem.baseDir().getPath() + getFileName()).exists() &&
                   FSNode(myOSystem.baseDir().getPath() + "KVSHARED.WAV").exists();

  #ifdef DEBUG_BUILD
    if(myFilesFound)
      cerr << "\nfound file: " << getFileName() << '\n'
           << "found file: " << "KVSHARED.WAV\n";
  #endif

    mySongLength = 0;
    mySongPointer = firstSongPointer[i];
  }
  myTapeBusy = false;
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void KidVid::setNextSong()
{
  if(myFilesFound)
  {
    myBeep = (ourSongPositions[mySongPointer] & 0x80) == 0;

    const uInt8 temp = ourSongPositions[mySongPointer] & 0x7f;
    mySongLength = ourSongStart[temp + 1] - ourSongStart[temp] - (262 * ClickFrames);

    // Play the WAV file
    const string& fileName = (temp < 10) ? "KVSHARED.WAV" : getFileName();
    myOSystem.sound().playWav(myOSystem.baseDir().getPath() + fileName,
                              ourSongStart[temp], mySongLength);
    ostringstream msg;
    msg << "Read song #" << mySongPointer << " (" << fileName << ")";
    myCallback(msg.str(), false);

  #ifdef DEBUG_BUILD
    cerr << fileName << ": " << (ourSongPositions[mySongPointer] & 0x7f) << '\n';
  #endif

    mySongPlaying = myTapeBusy = true;
    ++mySongPointer;
  }
  else
  {
    myBeep = true;
    myTapeBusy = true;
    mySongLength = TapeFrames + 32;   /* delay needed for Harmony without tape */
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const std::array<uInt8, KidVid::NumBlocks> KidVid::ourBlocks = {
  2+40, 2+21, 2+35,     /* Smurfs tapes 3, 1, 2 */
  42+60, 42+78, 42+60   /* BBears tapes 1, 2, 3 (40 extra blocks for intro) */
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const std::array<uInt8, KidVid::NumBlockBits> KidVid::ourData = {
/* KVData44, Smurfs */
  0x7b,  // 0111 1011b  ; (1)0
  0x1e,  // 0001 1110b  ; 1
  0xc6,  // 1100 0110b  ; 00
  0x31,  // 0011 0001b  ; 01
  0xec,  // 1110 1100b  ; 0
  0x60,  // 0110 0000b  ; 0+

/* KVData48, BBears */
  0x7b,  // 0111 1011b  ; (1)0
  0x1e,  // 0001 1110b  ; 1
  0xc6,  // 1100 0110b  ; 00
  0x3d,  // 0011 1101b  ; 10
  0x8c,  // 1000 1100b  ; 0
  0x60,  // 0110 0000b  ; 0+

/* KVData00 */
  0xf6,  // 1111 0110b
  0x31,  // 0011 0001b
  0x8c,  // 1000 1100b
  0x63,  // 0110 0011b
  0x18,  // 0001 1000b
  0xc0,  // 1100 0000b

/* KVData01 */
  0xf6,  // 1111 0110b
  0x31,  // 0011 0001b
  0x8c,  // 1000 1100b
  0x63,  // 0110 0011b
  0x18,  // 0001 1000b
  0xf0,  // 1111 0000b

/* KVData02 */
  0xf6,  // 1111 0110b
  0x31,  // 0011 0001b
  0x8c,  // 1000 1100b
  0x63,  // 0110 0011b
  0x1e,  // 0001 1110b
  0xc0,  // 1100 0000b

/* KVData03 */
  0xf6,  // 1111 0110b
  0x31,  // 0011 0001b
  0x8c,  // 1000 1100b
  0x63,  // 0110 0011b
  0x1e,  // 0001 1110b
  0xf0,  // 1111 0000b

/* KVPause */
  0x3f,  // 0011 1111b
  0xf0,  // 1111 0000b
  0x00,  // 0000 0000b
  0x00,  // 0000 0000b
  0x00,  // 0000 0000b
  0x00,  // 0000 0000b

/* KVData80 */
  0xf7,  // 1111 0111b  ; marks end of tape (green/yellow screen)
  0xb1,  // 1011 0001b
  0x8c,  // 1000 1100b
  0x63,  // 0110 0011b
  0x18,  // 0001 1000b
  0xc0   // 1100 0000b
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const std::array<uInt8, KidVid::SongPosSize> KidVid::ourSongPositions = {
/* kvs1 44 */
  11, 12+0x80, 13+0x80, 14, 15+0x80, 16, 8+0x80, 17, 18+0x80, 19, 20+0x80,
  21, 8+0x80, 22, 15+0x80, 23, 18+0x80, 14, 20+0x80, 16, 18+0x80,
  17, 15+0x80, 19, 8+0x80, 21, 20+0x80, 22, 18+0x80, 23, 15+0x80,
  14, 20+0x80, 16, 8+0x80, 22, 15+0x80, 23, 18+0x80, 14, 20+0x80,
  16, 8+0x80, 9,

/* kvs2 38 */
  25+0x80, 26, 27, 28, 8, 29, 30, 26, 27, 28, 8, 29, 30, 26, 27, 28, 8, 29,
  30, 26, 27, 28, 8, 29, 30, 26, 27, 28, 8, 29, 30, 26, 27, 28, 8, 29,
  30+0x80, 9,

/* kvs3 42 */
  32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 34, 42, 36, 43, 40, 39, 38, 37,
  34, 43, 36, 39, 40, 37, 38, 43, 34, 37, 36, 43, 40, 39, 38, 37, 34, 43,
  36, 39, 40, 37, 38+0x80, 9,

/* kvb1 62 */
  0, 1, 45, 2, 3, 46, 4, 5, 47, 6, 7, 48, 4, 3, 49, 2, 1, 50, 6, 7, 51,
  4, 5, 52, 6, 1, 53, 2, 7, 54, 6, 5, 45, 2, 1, 46, 4, 3, 47, 2, 5, 48,
  4, 7, 49, 6, 1, 50, 2, 5, 51, 6, 3, 52, 4, 7, 53, 2, 1, 54, 6+0x80, 9,

/* kvb2 80 */
  0, 1, 56, 4, 3, 57, 2, 5, 58, 6, 7, 59, 2, 3, 60, 4, 1, 61, 6, 7, 62,
  2, 5, 63, 6, 1, 64, 4, 7, 65, 6, 5, 66, 4, 1, 67, 2, 3, 68, 6, 5, 69,
  2, 7, 70, 4, 1, 71, 2, 5, 72, 4, 3, 73, 6, 7, 74, 2, 1, 75, 6, 3, 76,
  4, 5, 77, 6, 7, 78, 2, 3, 79, 4, 1, 80, 2, 7, 81, 4+0x80, 9,

/* kvb3 62 */
  0, 1, 83, 2, 3, 84, 4, 5, 85, 6, 7, 86, 4, 3, 87, 2, 1, 88, 6, 7, 89,
  2, 5, 90, 6, 1, 91, 4, 7, 92, 6, 5, 93, 4, 1, 94, 2, 3, 95, 6, 5, 96,
  2, 7, 97, 4, 1, 98, 6, 5, 99, 4, 3, 100, 2, 7, 101, 4, 1, 102, 2+0x80, 9
};

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const std::array<uInt32, KidVid::SongStartSize> KidVid::ourSongStart = {
/* kvshared */
  44,          /* Welcome + intro Berenstain Bears */
  980829,      /* boulders in the road */
  1178398,     /* standing ovations */
  1430063,     /* brother bear */
  1691136,     /* good work */
  1841665,     /* crossing a bridge */
  2100386,     /* not bad (applause) */
  2283843,     /* ourgame */
  2629588,     /* start the parade */
  2824805,     /* rewind */
  3059116,

/* kvs1 */
  44,          /* Harmony intro 1 */
  164685,      /* falling notes (intro 2) */
  395182,      /* instructions */
  750335,      /* high notes are high */
  962016,      /* my hat's off to you */
  1204273,     /* 1 2 3 do re mi */
  1538258,     /* Harmony */
  1801683,     /* congratulations (all of the Smurfs voted) */
  2086276,     /* line or space */
  2399093,     /* hooray */
  2589606,     /* hear yeeh */
  2801287,     /* over the river */
  3111752,     /* musical deduction */
  3436329,

/* kvs2 */
  44,          /* Handy intro + instructions */
  778557,      /* place in shape */
  1100782,     /* sailor mate + whistle */
//  1281887,
  1293648,     /* attention */
  1493569,     /* colours */
  1801682,     /* congratulations (Handy and friends voted) */
  2086275,

/* kvs3 */
  44,          /* Greedy and Clumsy intro + instructions */
  686829,      /* red */
  893806,      /* don't count your chicken */
  1143119,     /* yellow */
  1385376,     /* thank you */
  1578241,     /* mixin' and matchin' */
  1942802,     /* fun / colour shake */
  2168595,     /* colours can be usefull */
  2493172,     /* hip hip horay */
  2662517,     /* green */
  3022374,     /* purple */
  3229351,     /* white */
  3720920,

/* kvb1 */
  44,          /* 3 */ // can be one too late!
  592749,      /* 5 */
  936142,      /* 2 */
  1465343,     /* 4 */
  1787568,     /* 1 */
  2145073,     /* 7 */
  2568434,     /* 9 */
  2822451,     /* 8 */
  3045892,     /* 6 */
  3709157,     /* 0 */
  4219542,

/* kvb2 */
  44,          /* A */
  303453,      /* B */
  703294,      /* C */
  1150175,     /* D */
  1514736,     /* E */
  2208577,     /* F */
  2511986,     /* G */
  2864787,     /* H */
  3306964,     /* I */
  3864389,     /* J */
  4148982,     /* K */
  4499431,     /* L */
  4824008,     /* M */
  5162697,     /* N */
  5581354,     /* O */
  5844779,     /* P */
  6162300,     /* Q */
  6590365,     /* R */
  6839678,     /* S */
  7225407,     /* T */
  7552336,     /* U */
  7867505,     /* V */
  8316738,     /* W */
  8608387,     /* X */
  8940020,     /* Y */
  9274005,     /* Z */
  9593878,

/* kvb3 */
  44,          /* cat */
  341085,      /* one */
  653902,      /* red */
  1018463,     /* two */
  1265424,     /* dog */
  1669969,     /* six */
  1919282,     /* hat */
  2227395,     /* ten */
  2535508,     /* mom */
  3057653,     /* dad */
  3375174,     /* ball */
  3704455,     /* fish */
  4092536,     /* nine */
  4487673,     /* bear */
  5026282,     /* four */
  5416715,     /* bird */
  5670732,     /* tree */
  6225805,     /* rock */
  6736190,     /* book */
  7110159,     /* road */
  7676992
};
