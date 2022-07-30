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

#include "Missile.hxx"
#include "DrawCounterDecodes.hxx"
#include "TIA.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Missile::Missile(uInt32 collisionMask)
  : myCollisionMaskDisabled{collisionMask}
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::reset()
{
  myDecodes = DrawCounterDecodes::get().missileDecodes()[myDecodesOffset];
  myIsEnabled = false;
  myEnam = false;
  myResmp = 0;
  myHmmClocks = 0;
  myCounter = 0;
  isMoving = false;
  myWidth = 1;
  myEffectiveWidth = 1;
  myIsRendering = false;
  myIsVisible = false;
  myRenderCounter = 0;
  myCopy = 1;
  myColor = myObjectColor = myDebugColor = 0;
  myDebugEnabled = false;
  collision = myCollisionMaskDisabled;
  myInvertedPhaseClock = false;
  myUseInvertedPhaseClock = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::enam(uInt8 value)
{
  const auto oldEnam = myEnam;

  myEnam = (value & 0x02) > 0;

  if (oldEnam != myEnam) {
    myTIA->flushLineCache();

    updateEnabled();
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::hmm(uInt8 value)
{
  myHmmClocks = (value >> 4) ^ 0x08;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::resm(uInt8 counter, bool hblank)
{
  myCounter = counter;

  if (myIsRendering) {
    if (myRenderCounter < 0) {
      myRenderCounter = Count::renderCounterOffset + (counter - 157);

    } else {
      // The following is an effective description of the behavior of missile width after a
      // RESMx during draw. It would be much simpler without the HBLANK cases :)

      switch (myWidth) {
        case 8:
          myRenderCounter = (counter - 157) + ((myRenderCounter >= 4) ? 4 : 0);
          break;

        case 4:
          myRenderCounter = (counter - 157);
          break;

        case 2:
          if (hblank) myIsRendering = myRenderCounter > 1;
          else if (myRenderCounter == 0) ++myRenderCounter;

          break;

        default:
          if (hblank) myIsRendering = myRenderCounter > 0;

          break;
      }
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::resmp(uInt8 value, const Player& player)
{
  const uInt8 resmp = value & 0x02;

  if (resmp == myResmp) return;

  myTIA->flushLineCache();

  myResmp = resmp;

  if (!myResmp)
    myCounter = player.getRespClock();

  updateEnabled();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::toggleCollisions(bool enabled)
{
  myCollisionMaskEnabled = enabled ? 0xFFFF : (0x8000 | myCollisionMaskDisabled);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::toggleEnabled(bool enabled)
{
  myIsSuppressed = !enabled;
  updateEnabled();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::nusiz(uInt8 value)
{
  static constexpr std::array<uInt8, 4> ourWidths = { 1, 2, 4, 8 };

  myDecodesOffset = value & 0x07;
  myWidth = ourWidths[(value & 0x30) >> 4];
  myDecodes = DrawCounterDecodes::get().missileDecodes()[myDecodesOffset];

  if (myIsRendering && myRenderCounter >= myWidth)
    myIsRendering = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::startMovement()
{
  isMoving = true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::nextLine()
{
  myIsVisible = myIsRendering && (myRenderCounter >= 0);
  collision = (myIsVisible && myIsEnabled) ? myCollisionMaskEnabled : myCollisionMaskDisabled;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::setColor(uInt8 color)
{
  if (color != myObjectColor && myIsEnabled)  myTIA->flushLineCache();

  myObjectColor = color;
  applyColors();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::setDebugColor(uInt8 color)
{
  myTIA->flushLineCache();
  myDebugColor = color;
  applyColors();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::enableDebugColors(bool enabled)
{
  myTIA->flushLineCache();
  myDebugEnabled = enabled;
  applyColors();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::applyColorLoss()
{
  myTIA->flushLineCache();
  applyColors();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::setInvertedPhaseClock(bool enable)
{
  myUseInvertedPhaseClock = enable;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::updateEnabled()
{
  myIsEnabled = !myIsSuppressed && myEnam && !myResmp;

  collision = (myIsVisible && myIsEnabled) ? myCollisionMaskEnabled : myCollisionMaskDisabled;
  myTIA->scheduleCollisionUpdate();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::applyColors()
{
  if (!myDebugEnabled)
  {
    if (myTIA->colorLossActive()) myObjectColor |= 0x01;
    else                          myObjectColor &= 0xfe;
    myColor = myObjectColor;
  }
  else
    myColor = myDebugColor;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 Missile::getColor() const
{
  if(!myDebugEnabled)
    return myColor;
  else
    switch (myCopy)
    {
      case 2:
        return myColor - 2;
      case 3:
        return myColor + 2;
      default:
        return myColor;
    }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uInt8 Missile::getPosition() const
{
  // position =
  //    current playfield x +
  //    (current counter - 156 (the decode clock of copy 0)) +
  //    clock count after decode until first pixel +
  //    1 (it'll take another cycle after the decode for the rendter counter to start ticking)
  //
  // The result may be negative, so we add 160 and do the modulus
  //
  // Mind the sign of renderCounterOffset: it's defined negative above
  return (317 - myCounter - Count::renderCounterOffset + myTIA->getPosition()) % TIAConstants::H_PIXEL;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::setPosition(uInt8 newPosition)
{
  myTIA->flushLineCache();

  // See getPosition for an explanation
  myCounter = (317 - newPosition - Count::renderCounterOffset + myTIA->getPosition()) % TIAConstants::H_PIXEL;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Missile::save(Serializer& out) const
{
  try
  {
    out.putInt(collision);
    out.putInt(myCollisionMaskDisabled);
    out.putInt(myCollisionMaskEnabled);

    out.putBool(myIsEnabled);
    out.putBool(myIsSuppressed);
    out.putBool(myEnam);
    out.putByte(myResmp);

    out.putByte(myHmmClocks);
    out.putByte(myCounter);
    out.putBool(isMoving);
    out.putByte(myWidth);
    out.putByte(myEffectiveWidth);

    out.putBool(myIsVisible);
    out.putBool(myIsRendering);
    out.putByte(myRenderCounter);
    out.putByte(myCopy);

    out.putByte(myDecodesOffset);

    out.putByte(myColor);
    out.putByte(myObjectColor);  out.putByte(myDebugColor);
    out.putBool(myDebugEnabled);
    out.putBool(myInvertedPhaseClock);
  }
  catch(...)
  {
    cerr << "ERROR: TIA_Missile::save" << endl;
    return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool Missile::load(Serializer& in)
{
  try
  {
    collision = in.getInt();
    myCollisionMaskDisabled = in.getInt();
    myCollisionMaskEnabled = in.getInt();

    myIsEnabled = in.getBool();
    myIsSuppressed = in.getBool();
    myEnam = in.getBool();
    myResmp = in.getByte();

    myHmmClocks = in.getByte();
    myCounter = in.getByte();
    isMoving = in.getBool();
    myWidth = in.getByte();
    myEffectiveWidth = in.getByte();

    myIsVisible = in.getBool();
    myIsRendering = in.getBool();
    myRenderCounter = in.getByte();
    myCopy = in.getByte();

    myDecodesOffset = in.getByte();
    myDecodes = DrawCounterDecodes::get().missileDecodes()[myDecodesOffset];

    myColor = in.getByte();
    myObjectColor = in.getByte();  myDebugColor = in.getByte();
    myDebugEnabled = in.getBool();
    myInvertedPhaseClock = in.getBool();

    applyColors();
  }
  catch(...)
  {
    cerr << "ERROR: TIA_Missile::load" << endl;
    return false;
  }

  return true;
}
