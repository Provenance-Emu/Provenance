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

#ifndef KIDVID_HXX
#define KIDVID_HXX

class Event;
class Sound;

#include "bspf.hxx"
#include "Control.hxx"

/**
  The KidVid Voice Module, created by Coleco.  This class emulates the
  KVVM cassette player by mixing WAV data into the sound stream.  The
  WAV files are located at:

    http://www.atariage.com/2600/archives/KidVidAudio/index.html

  This code was heavily borrowed from z26.

  @author  Thomas Jentzsch & z26 team
*/
class KidVid : public Controller
{
  public:
    /**
      Create a new KidVid controller plugged into the specified jack

      @param jack      The jack the controller is plugged into
      @param event     The event object to use for events
      @param osystem   The OSystem object to use
      @param system    The system using this controller
      @param romMd5    The md5 of the ROM using this controller
      @param callback  Called to pass messages back to the parent controller
    */
    KidVid(Jack jack, const Event& event, const OSystem& osystem,
           const System& system, string_view romMd5,
           const onMessageCallbackForced& callback);
    ~KidVid() override = default;

  public:
    /**
      Write the given value to the specified digital pin for this
      controller.  Writing is only allowed to the pins associated
      with the PIA.  Therefore you cannot write to pin six.

      @param pin The pin of the controller jack to write to
      @param value The value to write to the pin
    */
    void write(DigitalPin pin, bool value) override;

    /**
      Update the entire digital and analog pin state according to the
      events currently set.
    */
    void update() override;

    /**
      Saves the current state of this controller to the given Serializer.

      @param out The serializer device to save to.
      @return The result of the save.  True on success, false on failure.
    */
    bool save(Serializer& out) const override;

    /**
      Loads the current state of this controller from the given Serializer.

      @param in The serializer device to load from.
      @return The result of the load.  True on success, false on failure.
    */
    bool load(Serializer& in) override;

    /**
      Returns the name of this controller.
    */
    string name() const override { return "KidVid"; }

  private:
    // Get name of the current sample file
    const char* getFileName() const;

    // Open/close a WAV sample file
    void openSampleFiles();

    // Jump to next song in the sequence
    void setNextSong();

  private:
    enum class Game {
      Smurfs,
      BBears
    };
    static constexpr uInt32
      NumBlocks     = 6,              // number of bytes / block
      NumBlockBits  = NumBlocks * 8,  // number of bits / block
      SongPosSize   = 44 + 38 + 42 + 62 + 80 + 62,
      SongStartSize = 104,
      TapeFrames    = 60,
      ClickFrames   = 3               // eliminate click noise at song end
    ;

    // Whether the KidVid device is enabled (only for games that it
    // supports, and if it's plugged into the right port)
    bool myEnabled{false};

    const OSystem& myOSystem;

    // Sends messages back to the parent class
    Controller::onMessageCallbackForced myCallback;

    // Indicates if the sample files have been found
    bool myFilesFound{false};

    // Is the tape currently 'busy' / in use?
    bool myTapeBusy{false};

    bool mySongPlaying{false};
    // Continue song after loading state?
    bool myContinueSong{false};

    uInt32 mySongPointer{0};
    uInt32 mySongLength{0};
    bool myBeep{false};
    Game myGame{Game::Smurfs};
    uInt32 myTape{0};
    uInt32 myIdx{0}, myBlock{0}, myBlockIdx{0};

    // Number of blocks and data on tape
    static const std::array<uInt8, NumBlocks> ourBlocks;
    static const std::array<uInt8, NumBlockBits> ourData;

    static const std::array<uInt8, SongPosSize> ourSongPositions;
    static const std::array<uInt32, SongStartSize> ourSongStart;

  private:
    // Following constructors and assignment operators not supported
    KidVid() = delete;
    KidVid(const KidVid&) = delete;
    KidVid(KidVid&&) = delete;
    KidVid& operator=(const KidVid&) = delete;
    KidVid& operator=(KidVid&&) = delete;
};

#endif
