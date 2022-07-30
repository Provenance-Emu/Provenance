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
// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef KIDVID_HXX
#define KIDVID_HXX

#include <cstdio>

class Event;

#include "bspf.hxx"
#include "Control.hxx"

/**
  The KidVid Voice Module, created by Coleco.  This class emulates the
  KVVM cassette player by mixing WAV data into the sound stream.  The
  WAV files are located at:

    http://www.atariage.com/2600/archives/KidVidAudio/index.html

  This code was heavily borrowed from z26.

  @author  Stephen Anthony & z26 team
*/
class KidVid : public Controller
{
  public:
    /**
      Create a new KidVid controller plugged into the specified jack

      @param jack   The jack the controller is plugged into
      @param event  The event object to use for events
      @param system The system using this controller
      @param romMd5 The md5 of the ROM using this controller
    */
    KidVid(Jack jack, const Event& event, const System& system,
           const string& romMd5);
    ~KidVid() override;

  public:
    /**
      Update the entire digital and analog pin state according to the
      events currently set.
    */
    void update() override;

    /**
      Returns the name of this controller.
    */
    string name() const override { return "KidVid"; }

  private:
    // Open/close a WAV sample file
    void openSampleFile();
    void closeSampleFile();

    // Jump to next song in the sequence
    void setNextSong();

    // Generate next sample byte
    // TODO - rework this, perhaps send directly to sound class
    void getNextSampleByte();

  private:
    static constexpr uInt32
      KVSMURFS = 0x44,
      KVBBEARS = 0x48,
      KVBLOCKS = 6,             // number of bytes / block
      KVBLOCKBITS = KVBLOCKS*8, // number of bits / block
      SONG_POS_SIZE   = 44+38+42+62+80+62,
      SONG_START_SIZE = 104
    ;

    // Whether the KidVid device is enabled (only for games that it
    // supports, and if it's plugged into the right port
    bool myEnabled{false};

    // The file handles for the WAV files
    // FILE *mySampleFile, *mySharedSampleFile;

    // Indicates if sample files have been successfully opened
    bool myFileOpened{false};

    // Is the tape currently 'busy' / in use?
    bool myTapeBusy{false};

    uInt32 myFilePointer{0}, mySongCounter{0};
    bool myBeep{false}, mySharedData{false};
    uInt8 mySampleByte{0};
    uInt32 myGame{0}, myTape{0};
    uInt32 myIdx{0}, myBlock{0}, myBlockIdx{0};

    // Number of blocks and data on tape
    static const std::array<uInt8, KVBLOCKS> ourKVBlocks;
    static const std::array<uInt8, KVBLOCKBITS> ourKVData;

    static const std::array<uInt8, SONG_POS_SIZE> ourSongPositions;
    static const std::array<uInt32, SONG_START_SIZE> ourSongStart;

  private:
    // Following constructors and assignment operators not supported
    KidVid() = delete;
    KidVid(const KidVid&) = delete;
    KidVid(KidVid&&) = delete;
    KidVid& operator=(const KidVid&) = delete;
    KidVid& operator=(KidVid&&) = delete;
};

#endif
