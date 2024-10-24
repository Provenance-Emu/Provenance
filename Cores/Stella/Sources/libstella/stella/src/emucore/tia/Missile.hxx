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

#ifndef TIA_MISSILE
#define TIA_MISSILE

class TIA;
class Player;

#include "Serializable.hxx"
#include "bspf.hxx"
#include "TIAConstants.hxx"

class Missile : public Serializable
{
  public:

    explicit Missile(uInt32 collisionMask);

  public:

    void setTIA(TIA* tia) { myTIA = tia; }

    void reset();

    void enam(uInt8 value);

    void hmm(uInt8 value);

    void resm(uInt8 counter, bool hblank);

    void resmp(uInt8 value, const Player& player);

    void nusiz(uInt8 value);

    void startMovement();

    void nextLine();

    void setColor(uInt8 color);

    void setDebugColor(uInt8 color);
    void enableDebugColors(bool enabled);

    void applyColorLoss();

    void setInvertedPhaseClock(bool enable);

    void toggleCollisions(bool enabled);

    void toggleEnabled(bool enabled);

    inline bool isOn() const { return (collision & 0x8000); }
    uInt8 getColor() const;

    uInt8 getPosition() const;
    void setPosition(uInt8 newPosition);

    /**
      Serializable methods (see that class for more information).
    */
    bool save(Serializer& out) const override;
    bool load(Serializer& in) override;

    FORCE_INLINE void movementTick(uInt8 clock, uInt8 hclock, bool hblank);

    FORCE_INLINE void tick(uInt8 hclock, bool isReceivingMclock = true);

  public:

    uInt32 collision{0};
    bool isMoving{false};

  private:

    void updateEnabled();
    void applyColors();

  private:

    enum Count: Int8 {
      renderCounterOffset = -4
    };

  private:

    uInt32 myCollisionMaskDisabled{0};
    uInt32 myCollisionMaskEnabled{0xFFFF};

    bool myIsEnabled{false};
    bool myIsSuppressed{false};
    bool myEnam{false};
    uInt8 myResmp{0};

    uInt8 myHmmClocks{0};
    uInt8 myCounter{0};

    uInt8 myWidth{1};
    uInt8 myEffectiveWidth{1};

    bool myIsRendering{false};
    bool myIsVisible{false};
    Int8 myRenderCounter{0};
    Int8 myCopy{1};

    const uInt8* myDecodes{nullptr};
    uInt8 myDecodesOffset{0};  // needed for state saving

    uInt8 myColor{0};
    uInt8 myObjectColor{0}, myDebugColor{0};
    bool myDebugEnabled{false};

    bool myInvertedPhaseClock{false};
    bool myUseInvertedPhaseClock{false};

    TIA *myTIA{nullptr};

  private:
    Missile(const Missile&) = delete;
    Missile(Missile&&) = delete;
    Missile& operator=(const Missile&) = delete;
    Missile& operator=(Missile&&) = delete;
};

// ############################################################################
// Implementation
// ############################################################################

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::movementTick(uInt8 clock, uInt8 hclock, bool hblank)
{
  if(isMoving)
  {
    // Stop movement once the number of clocks according to HMMx is reached
    if(clock == myHmmClocks)
      isMoving = false;
    else
    {
      // Process the tick if we are in hblank. Otherwise, the tick is either masked
      // by an ordinary tick or merges two consecutive ticks into a single tick (inverted
      // movement clock phase mode).
      if(hblank) tick(hclock, false);
      // Track a tick outside hblank for later processing
      myInvertedPhaseClock = !hblank;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Missile::tick(uInt8 hclock, bool isReceivingMclock)
{
  // If we are in inverted movement clock phase mode and a movement tick occurred, it
  // will supress the tick.
  if(myUseInvertedPhaseClock && myInvertedPhaseClock)
  {
    myInvertedPhaseClock = false;
    return;
  }

  myIsVisible =
    myIsRendering &&
    (myRenderCounter >= 0 || (isMoving && isReceivingMclock && myRenderCounter == -1 && myWidth < 4 && ((hclock + 1) % 4 == 3)));

  // Consider enabled status and the signal to determine visibility (as represented
  // by the collision mask)
  collision = (myIsVisible && myIsEnabled) ? myCollisionMaskEnabled : myCollisionMaskDisabled;

  if (myDecodes[myCounter] && !myResmp) {
    myIsRendering = true;
    myRenderCounter = renderCounterOffset;
    myCopy = myDecodes[myCounter];
  } else if (myIsRendering) {

      if (myRenderCounter == -1) {
        // Regular clock pulse during movement -> starfield mode
        if (isMoving && isReceivingMclock) {
          switch ((hclock + 1) % 4) {
            case 3:
              myEffectiveWidth = myWidth == 1 ? 2 : myWidth;
              if (myWidth < 4) ++myRenderCounter;
              break;

            case 2:
              myEffectiveWidth = 0;
              break;

            default:
              myEffectiveWidth = myWidth;
              break;
          }
        } else {
          myEffectiveWidth = myWidth;
        }
      }

      if (++myRenderCounter >= (isMoving ? myEffectiveWidth : myWidth)) myIsRendering = false;
  }

  if (++myCounter >= TIAConstants::H_PIXEL) myCounter = 0;
}

#endif // TIA_MISSILE
