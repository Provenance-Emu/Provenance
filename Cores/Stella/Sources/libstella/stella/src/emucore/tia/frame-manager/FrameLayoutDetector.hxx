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

#ifndef TIA_FRAME_LAYOUT_DETECTOR
#define TIA_FRAME_LAYOUT_DETECTOR

class M6532;
class EventHandler;

#include "FrameLayout.hxx"
#include "AbstractFrameManager.hxx"
#include "TIAConstants.hxx"

/**
 * This frame manager performs frame layout autodetection. It counts the scanlines
 * in each frame and assigns guesses the frame layout from this.
 */
class FrameLayoutDetector: public AbstractFrameManager
{
  public:

    FrameLayoutDetector();

  public:

    /**
     * Return the detected frame layout.
     */
    FrameLayout detectedLayout(bool detectPal60 = false,
                               bool detectNtsc50 = false,
                               string_view name = EmptyString) const;

    /**
     * Simulate some input to pass a potential title screen.
    */
    static void simulateInput(M6532& riot, EventHandler& eventHandler,
                              bool pressed);

  protected:
    /**
     * Hook into vsync changes.
     */
    void onSetVsync(uInt64) override;

    /**
     * Hook into reset.
     */
    void onReset() override;

    /**
     * Hook into line changes.
     */
    void onNextLine() override;

    /**
     * Called when a pixel is rendered.
    */
    void pixelColor(uInt8 color) override;

  private:
    /**
     * This frame manager only tracks frame boundaries, so we have only two states.
     */
    enum class State {
      // Wait for VSYNC to be enabled.
      waitForVsyncStart,

      // Wait for VSYNC to be disabled.
      waitForVsyncEnd
    };

    /**
     * Misc. numeric constants used in the algorithm.
     */
    enum Metrics: uInt32 {
      // ideal frame heights
      frameLinesNTSC            = 262,
      frameLinesPAL             = 312,

      // number of scanlines to wait for vsync to start and stop
      // (exceeding ideal frame height)
      waitForVsync              = 100,

      // these frames will not be considered for detection
      initialGarbageFrames      = TIAConstants::initialGarbageFrames
    };

  private:
    /**
     * Change state and change internal state accordingly.
     */
    void setState(State state);

    /**
     * Finalize the current frame and guess frame layout from the scanline count.
     */
    void finalizeFrame();

  private:
    /**
     * The current state.
     */
    State myState{State::waitForVsyncStart};

    // The aggregated likelynesses of respective two frame layouts.
    double myNtscFrameSum{0}, myPalFrameSum{0};

    /**
     * We count the number of scanlines we spend waiting for vsync to be
     * toggled. If a threshold is exceeded, we force the transition.
     */
    uInt32 myLinesWaitingForVsyncToStart{0};

    /**
     * We count the number of pixels for each colors used. These are
     * evaluated against statistical color distributions and, if
     * decisive, allow overruling the scanline results.
    */
    static constexpr int NUM_HUES = 16;
    static constexpr int NUM_LUMS = 8;
    std::array<uInt64, NUM_HUES * NUM_LUMS> myColorCount{0};

  private:
    FrameLayoutDetector(const FrameLayoutDetector&) = delete;
    FrameLayoutDetector(FrameLayoutDetector&&) = delete;
    FrameLayoutDetector& operator=(const FrameLayoutDetector&) = delete;
    FrameLayoutDetector& operator=(FrameLayoutDetector&&) = delete;

};

#endif // TIA_FRAME_LAYOUT_DETECTOR
