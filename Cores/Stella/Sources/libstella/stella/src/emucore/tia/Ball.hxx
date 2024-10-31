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

#ifndef TIA_BALL
#define TIA_BALL

class TIA;

#include "bspf.hxx"
#include "TIAConstants.hxx"
#include "Serializable.hxx"

class Ball : public Serializable
{
  public:

    /**
      The collision mask is injected at construction
     */
    explicit Ball(uInt32 collisionMask);

  public:

    /**
      Set the TIA instance
     */
    void setTIA(TIA* tia) { myTIA = tia; }

    /**
      Reset to initial state.
     */
    void reset();

    /**
      ENABL write.
     */
    void enabl(uInt8 value);

    /**
      HMBL write.
     */
    void hmbl(uInt8 value);

    /**
      RESBL write.
     */
    void resbl(uInt8 counter);

    /**
      CTRLPF write.
      */
    void ctrlpf(uInt8 value);

    /**
      VDELBL write.
     */
    void vdelbl(uInt8 value);

    /**
      Enable / disable ball display (debugging only, not used during normal emulation).
     */
    void toggleEnabled(bool enabled);

    /**
      Enable / disable ball collisions (debugging only, not used during normal emulation).
     */
    void toggleCollisions(bool enabled);

    /**
      Set color PF.
     */
    void setColor(uInt8 color);

    /**
      Set the color used in "debug colors" mode.
     */
    void setDebugColor(uInt8 color);

    /**
      Enable "debug colors" mode.
     */

    void enableDebugColors(bool enabled);

    /**
      Update internal state to use the color loss palette.
     */
    void applyColorLoss();

    /**
      Switch to "inverted phase" mode. This mode emulates the phase shift
      between movement and ordinary clock pulses that is exhibited by some
      TIA revisions and that give rise to glitches like the infamous Cool
      Aid Man bug on some Jr. models.
     */
    void setInvertedPhaseClock(bool enable);

    /**
      Start movement --- this is triggered by strobing HMOVE.
     */
    void startMovement();

    /**
      Notify ball of line change.
     */
    void nextLine();

    /**
      Is the ball visible? This is determined by looking at bit 15
      of the collision mask.
     */
    inline bool isOn() const { return (collision & 0x8000); }

    /**
      Get the current color.
     */
    inline uInt8 getColor() const { return myColor; }

    /**
      Shuffle the enabled flag. This is called in VDELBL mode when GRP1 is
      written (with a delay of one cycle).
     */
    void shuffleStatus();

    /**
      Calculate the sprite position from the counter. Used by the debugger only.
     */
    uInt8 getPosition() const;

    /**
      Set the counter and place the sprite at a specified position. Used by the debugger
      only.
     */
    void setPosition(uInt8 newPosition);

    /**
      Get the "old" and "new" values of the enabled flag. Used by the debuggger only.
     */
    bool getENABLOld() const { return myIsEnabledOld; }
    bool getENABLNew() const { return myIsEnabledNew; }

    /**
      Directly set the "old" value of the enabled flag. Used by the debugger only.
     */
    void setENABLOld(bool enabled);

    /**
      Serializable methods (see that class for more information).
    */
    bool save(Serializer& out) const override;
    bool load(Serializer& in) override;

    /**
      Process a single movement tick. Inline for performance (implementation below).
     */
    FORCE_INLINE void movementTick(uInt32 clock, bool hblank);

    /**
      Tick one color clock. Inline for performance (implementation below).
     */
    FORCE_INLINE void tick(bool isReceivingRegularClock = true);

  public:

    /**
      16 bit Collision mask. Each sprite is represented by a single bit in the mask
      (1 = active, 0 = inactive). All other bits are always 1. The highest bit is
      abused to store visibility (as the actual collision bit will always be zero
      if collisions are disabled).
     */
    uInt32 collision{0};

    /**
      The movement flag. This corresponds to the state of the movement latch for
      this sprite --- true while movement is active and ticks are still propagated
      to the counters, false otherwise.
     */
    bool isMoving{false};

  private:

    /**
      Recalculate enabled / disabled state. This is not the same as the enabled / disabled
      flag, but rather calculated from the flag and the corresponding debug setting.
     */
    void updateEnabled();

    /**
      Recalculate ball color based on COLUPF, debug colors, color loss, etc.
     */
    void applyColors();

  private:

    /**
      Offset of the render counter when rendering starts. Actual display starts at zero,
      so this amounts to a delay.
     */
    enum Count: Int8 {
      renderCounterOffset = -4
    };

  private:

    /**
      Collision mask values for active / inactive states. Disabling collisions
      will change those.
     */
    uInt32 myCollisionMaskDisabled{0};
    uInt32 myCollisionMaskEnabled{0xFFFF};

    /**
      Color value calculated by applyColors().
     */
    uInt8 myColor{0};

    /**
      Color configured by COLUPF
     */
    uInt8 myObjectColor{0};

    /**
      Color for debug mode.
     */
    uInt8 myDebugColor{0};

    /**
      Debug mode enabled?
     */
    bool myDebugEnabled{false};

    /**
      "old" and "new" values of the enabled flag.
     */
    bool myIsEnabledOld{false};
    bool myIsEnabledNew{false};

    /**
      Actual value of the enabled flag. Determined from the "old" and "new" values
      VDEL, debug settings etc.
     */
    bool myIsEnabled{false};

    /**
      Is the sprite turned off in the debugger?
     */
    bool myIsSuppressed{false};

    /**
      Is VDEL active?
     */
    bool myIsDelaying{false};

    /**
     Is the ball sprite signal currently active?
    */
    bool mySignalActive{false};

    /**
      HMM clocks before movement stops. Changed by writing to HMBL.
     */
    uInt8 myHmmClocks{0};

    /**
      The sprite counter
     */
    uInt8 myCounter{0};

    /**
      Ball width, as configured by CTRLPF.
     */
    uInt8 myWidth{1};

    /**
      Effective width used for drawing. This is usually the same as myWidth,
      but my differ in starfield mode.
     */
    uInt8 myEffectiveWidth{1};

    /**
      The value of the counter value at which the last movement tick occurred. This is
      used for simulating the starfield pattern.
     */
    uInt8 myLastMovementTick{0};

    /**
      Are we currently rendering? This is latched when the counter hits it decode value,
      or when RESBL is strobed. It is turned off once the render counter reaches its
      maximum (i.e. when the sprite has been fully displayed).
     */
    bool myIsRendering{false};

    /**
      Rendering counter. It starts counting (below zero) when the counter hits the decode value,
      and the actual signal becomes active once it reaches 0.
     */
    Int8 myRenderCounter{0};

    /**
      This memorizes a movement tick outside HBLANK in inverted clock mode. It is latched
      durin ::movementTick() and processed during ::tick() where it inhibits the clock
      pulse.
     */
    bool myInvertedPhaseClock{false};

    /**
      Use "inverted movement clock phase" mode? This emulates an idiosyncracy of several
      newer TIA revisions (see the setter above for a deeper explanation).
     */
    bool myUseInvertedPhaseClock{false};

    /**
      TIA instance. Required for flushing the line cache and requesting collision updates.
     */
    TIA* myTIA{nullptr};

  private:
    Ball() = delete;
    Ball(const Ball&) = delete;
    Ball(Ball&&) = delete;
    Ball& operator=(const Ball&) = delete;
    Ball& operator=(Ball&&) = delete;
};

// ############################################################################
// Implementation
// ############################################################################

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Ball::movementTick(uInt32 clock, bool hblank)
{
  myLastMovementTick = myCounter;

  if(isMoving)
  {
    // Stop movement once the number of clocks according to HMBL is reached
    if (clock == myHmmClocks)
      isMoving = false;
    else
    {
      // Process the tick if we are in hblank. Otherwise, the tick is either masked
      // by an ordinary tick or merges two consecutive ticks into a single tick (inverted
      // movement clock phase mode).
      if(hblank) tick(false);
      // Track a tick outside hblank for later processing
      myInvertedPhaseClock = !hblank;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Ball::tick(bool isReceivingRegularClock)
{
  // If we are in inverted movement clock phase mode and a movement tick occurred, it
  // will supress the tick.
  if(myUseInvertedPhaseClock && myInvertedPhaseClock)
  {
    myInvertedPhaseClock = false;
    return;
  }

  // Turn on the signal if the render counter reaches the threshold
  mySignalActive = myIsRendering && myRenderCounter >= 0;

  // Consider enabled status and the signal to determine visibility (as represented
  // by the collision mask)
  collision = (mySignalActive && myIsEnabled) ? myCollisionMaskEnabled : myCollisionMaskDisabled;

  // Regular clock pulse during movement -> starfield mode
  const bool starfieldEffect = isMoving && isReceivingRegularClock;

  // Decode value that triggers rendering
  if (myCounter == 156) {
    myIsRendering = true;
    myRenderCounter = renderCounterOffset;

    // What follows is an effective description of ball width in starfield mode.
    const uInt8 starfieldDelta = (myCounter + TIAConstants::H_PIXEL - myLastMovementTick) % 4;
    if (starfieldEffect && starfieldDelta == 3 && myWidth < 4) ++myRenderCounter;

    switch (starfieldDelta) {
      case 3:
        myEffectiveWidth = myWidth == 1 ? 2 : myWidth;
        break;

      case 2:
        myEffectiveWidth = 0;
        break;

      default:
        myEffectiveWidth = myWidth;
        break;
    }

  } else if (myIsRendering && ++myRenderCounter >= (starfieldEffect ? myEffectiveWidth : myWidth))
    myIsRendering = false;

  if (++myCounter >= TIAConstants::H_PIXEL)
      myCounter = 0;
}

#endif // TIA_BALL
