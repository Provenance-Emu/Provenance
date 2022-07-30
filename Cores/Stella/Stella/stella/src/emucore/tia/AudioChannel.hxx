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

#ifndef TIA_AUDIO_CHANNEL_HXX
#define TIA_AUDIO_CHANNEL_HXX

#include "bspf.hxx"
#include "Serializable.hxx"

class AudioChannel : public Serializable
{
  public:
    AudioChannel() = default;

    void reset();

    void phase0();

    uInt8 phase1();

    void audc(uInt8 value);

    void audf(uInt8 value);

    void audv(uInt8 value);

    /**
      Serializable methods (see that class for more information).
    */
    bool save(Serializer& out) const override;
    bool load(Serializer& in) override;

  private:
    uInt8 myAudc{0};
    uInt8 myAudv{0};
    uInt8 myAudf{0};

    bool myClockEnable{false};
    bool myNoiseFeedback{false};
    bool myNoiseCounterBit4{false};
    bool myPulseCounterHold{false};

    uInt8 myDivCounter{0};
    uInt8 myPulseCounter{0};
    uInt8 myNoiseCounter{0};

  private:
    AudioChannel(const AudioChannel&) = delete;
    AudioChannel(AudioChannel&&) = delete;
    AudioChannel& operator=(const AudioChannel&) = delete;
    AudioChannel& operator=(AudioChannel&&) = delete;
};

#endif // TIA_AUDIO_CHANNEL_HXX
