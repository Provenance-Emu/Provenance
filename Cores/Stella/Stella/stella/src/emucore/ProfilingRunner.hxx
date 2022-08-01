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

#ifndef PROFILING_RUNNER
#define PROFILING_RUNNER

#include "bspf.hxx"
#include "Control.hxx"
#include "Switches.hxx"
#include "Settings.hxx"
#include "ConsoleIO.hxx"
#include "Props.hxx"

class ProfilingRunner {
  public:

    ProfilingRunner(int argc, char* argv[]);

    bool run();

  private:

    struct ProfilingRun {
      string romFile;
      uInt32 runtime{0};
    };

    struct IO: public ConsoleIO {
      Controller& leftController() const override { return *myLeftControl; }
      Controller& rightController() const override { return *myRightControl; }
      Switches& switches() const override { return *mySwitches; }

      unique_ptr<Controller> myLeftControl;
      unique_ptr<Controller> myRightControl;
      unique_ptr<Switches> mySwitches;
    };

  private:

    bool runOne(const ProfilingRun& run);

  private:

    vector<ProfilingRun> profilingRuns;

    Settings mySettings;

    Properties myProps;
};

#endif // PROFILING_RUNNER
