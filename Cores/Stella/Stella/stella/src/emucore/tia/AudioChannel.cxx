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

#include "AudioChannel.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioChannel::reset()
{
  myAudc = myAudv = myAudf = 0;
  myClockEnable = myNoiseFeedback = myNoiseCounterBit4 = myPulseCounterHold = false;
  myDivCounter = myPulseCounter = myNoiseCounter = 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioChannel::phase0()
{
  if (myClockEnable) {
    myNoiseCounterBit4 = myNoiseCounter & 0x01;

    switch (myAudc & 0x03) {
      case 0x00:
      case 0x01:
        myPulseCounterHold = false;
        break;

      case 0x02:
        myPulseCounterHold = (myNoiseCounter & 0x1e) != 0x02;
        break;

      case 0x03:
        myPulseCounterHold = !myNoiseCounterBit4;
        break;

      default:  // not possible, but silence the compiler
        break;
    }

    switch (myAudc & 0x03) {
      case 0x00:
        myNoiseFeedback =
          ((myPulseCounter ^ myNoiseCounter) & 0x01) ||
          !(myNoiseCounter || (myPulseCounter != 0x0a)) ||
          !(myAudc & 0x0c);

        break;

      default:
        myNoiseFeedback =
          (((myNoiseCounter & 0x04) ? 1 : 0) ^ (myNoiseCounter & 0x01)) ||
          myNoiseCounter == 0;

      break;
    }
  }

  myClockEnable = myDivCounter == myAudf;

  if (myDivCounter == myAudf || myDivCounter == 0x1f) {
    myDivCounter = 0;
  } else {
    ++myDivCounter;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 AudioChannel::phase1()
{
  if (myClockEnable) {
    bool pulseFeedback = false;
    switch (myAudc >> 2) {
      case 0x00:
        pulseFeedback =
          (((myPulseCounter & 0x02) ? 1 : 0) ^ (myPulseCounter & 0x01)) &&
          (myPulseCounter != 0x0a) &&
          (myAudc & 0x03);
        break;

      case 0x01:
        pulseFeedback = !(myPulseCounter & 0x08);
        break;

      case 0x02:
        pulseFeedback = !myNoiseCounterBit4;
        break;

      case 0x03:
        pulseFeedback = !((myPulseCounter & 0x02) || !(myPulseCounter & 0x0e));
        break;

      default:
        break;
    }

    myNoiseCounter >>= 1;
    if (myNoiseFeedback) {
      myNoiseCounter |= 0x10;
    }

    if (!myPulseCounterHold) {
      myPulseCounter = ~(myPulseCounter >> 1) & 0x07;

      if (pulseFeedback) {
        myPulseCounter |= 0x08;
      }
    }
  }

  return (myPulseCounter & 0x01) * myAudv;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioChannel::audc(uInt8 value)
{
  myAudc = value & 0x0f;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioChannel::audv(uInt8 value)
{
  myAudv = value & 0x0f;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void AudioChannel::audf(uInt8 value)
{
  myAudf = value & 0x1f;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool AudioChannel::save(Serializer& out) const
{
  try
  {
    out.putByte(myAudc);
    out.putByte(myAudv);
    out.putByte(myAudf);

    out.putBool(myClockEnable);
    out.putBool(myNoiseFeedback);
    out.putBool(myNoiseCounterBit4);
    out.putBool(myPulseCounterHold);

    out.putByte(myDivCounter);
    out.putByte(myPulseCounter);
    out.putByte(myNoiseCounter);
  }
  catch(...)
  {
    cerr << "ERROR: TIA_AudioChannel::save" << endl;
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool AudioChannel::load(Serializer& in)
{
  try
  {
    myAudc = in.getByte();
    myAudv = in.getByte();
    myAudf = in.getByte();

    myClockEnable = in.getBool();
    myNoiseFeedback = in.getBool();
    myNoiseCounterBit4 = in.getBool();
    myPulseCounterHold = in.getBool();

    myDivCounter = in.getByte();
    myPulseCounter = in.getByte();
    myNoiseCounter = in.getByte();
  }
  catch(...)
  {
    cerr << "ERROR: TIA_AudioChannel::load" << endl;
    return false;
  }

  return true;
}
