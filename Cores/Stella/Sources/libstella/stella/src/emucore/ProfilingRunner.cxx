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

#include <chrono>

#include "ProfilingRunner.hxx"
#include "FSNode.hxx"
#include "Cart.hxx"
#include "CartCreator.hxx"
#include "MD5.hxx"
#include "Control.hxx"
#include "M6502.hxx"
#include "M6532.hxx"
#include "TIA.hxx"
#include "ConsoleTiming.hxx"
#include "FrameManager.hxx"
#include "FrameLayoutDetector.hxx"
#include "EmulationTiming.hxx"
#include "System.hxx"
#include "Joystick.hxx"
#include "Random.hxx"
#include "DispatchResult.hxx"

using namespace std::chrono;

namespace {
  constexpr uInt32 RUNTIME_DEFAULT = 60;

  void updateProgress(uInt32 from, uInt32 to) {
    while (from < to) {
      if (from % 10 == 0 && from > 0) cout << from << "%";
      else cout << ".";

      cout.flush();

      from++;
    }
  }
} // namespace

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ProfilingRunner::ProfilingRunner(int argc, char* argv[])
  : profilingRuns{std::max<size_t>(argc - 2, 0)}
{
  for (int i = 2; i < argc; i++) {
    ProfilingRun& run(profilingRuns[i-2]);

    const string arg = argv[i];
    const size_t splitPoint = arg.find_first_of(':');

    run.romFile = splitPoint == string::npos ? arg : arg.substr(0, splitPoint);

    if (splitPoint == string::npos) run.runtime = RUNTIME_DEFAULT;
    else  {
      const int runtime = BSPF::stoi(arg.substr(splitPoint+1, string::npos));
      run.runtime = runtime > 0 ? runtime : RUNTIME_DEFAULT;
    }
  }

  mySettings.setValue("fastscbios", true);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool ProfilingRunner::run()
{
  cout << "Profiling Stella...\n";

  for (const ProfilingRun& run : profilingRuns) {
    cout << "\nrunning " << run.romFile << " for " << run.runtime
         << " seconds...\n";

    if (!runOne(run)) return false;
  }

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// FIXME
// Warning	C6262	Function uses '301164' bytes of stack : exceeds / analyze :
//                stacksize '16384'.  Consider moving some data to heap.
bool ProfilingRunner::runOne(const ProfilingRun& run)
{
  const FSNode imageFile(run.romFile);

  if (!imageFile.isFile()) {
    cout << "ERROR: " << run.romFile << " is not a ROM image\n";
    return false;
  }

  ByteBuffer image;
  const size_t size = imageFile.read(image);
  if (size == 0) {
    cout << "ERROR: unable to read " << run.romFile << '\n';
    return false;
  }

  string md5 = MD5::hash(image, size);
  const string type;
  unique_ptr<Cartridge> cartridge = CartCreator::create(
      imageFile, image, size, md5, type, mySettings);

  if (!cartridge) {
    cout << "ERROR: unable to determine cartridge type\n";
    return false;
  }

  IO consoleIO;
  Random rng(0);
  const Event event;

  M6502 cpu(mySettings);
  M6532 riot(consoleIO, mySettings);

  const TIA::onPhosphorCallback callback = [] (bool enable) {};

  TIA tia(consoleIO, []() { return ConsoleTiming::ntsc; }, mySettings, callback);
  System system(rng, cpu, riot, tia, *cartridge);

  consoleIO.myLeftControl = make_unique<Joystick>(Controller::Jack::Left, event, system);
  consoleIO.myRightControl = make_unique<Joystick>(Controller::Jack::Right, event, system);
  consoleIO.mySwitches = make_unique<Switches>(event, myProps, mySettings);

  tia.bindToControllers();
  cartridge->setStartBankFromPropsFunc([]() { return -1; });
  system.initialize();

  FrameLayoutDetector frameLayoutDetector;
  tia.setFrameManager(&frameLayoutDetector);
  system.reset();

  (cout << "detecting frame layout... ").flush();
  for(int i = 0; i < 60; ++i) tia.update();

  const FrameLayout frameLayout = frameLayoutDetector.detectedLayout();
  ConsoleTiming consoleTiming = ConsoleTiming::ntsc;

  switch (frameLayout) {
    case FrameLayout::ntsc:
      cout << "NTSC";
      consoleTiming = ConsoleTiming::ntsc;
      break;

    case FrameLayout::pal:
      cout << "PAL";
      consoleTiming = ConsoleTiming::pal;
      break;

    default:  // TODO: add other layouts here
      break;
  }

  (cout << '\n').flush();

  FrameManager frameManager;
  tia.setFrameManager(&frameManager);
  tia.setLayout(frameLayout);

  system.reset();

  const EmulationTiming emulationTiming(frameLayout, consoleTiming);
  uInt64 cycles = 0;
  const uInt64 cyclesTarget = static_cast<uInt64>(run.runtime) * emulationTiming.cyclesPerSecond();

  DispatchResult dispatchResult;
  dispatchResult.setOk(0);

  uInt32 percent = 0;
  (cout << "0%").flush();

  const time_point<high_resolution_clock> tp = high_resolution_clock::now();

  while (cycles < cyclesTarget && dispatchResult.getStatus() == DispatchResult::Status::ok) {
    tia.update(dispatchResult);
    cycles += dispatchResult.getCycles();

    if (tia.newFramePending()) tia.renderToFrameBuffer();

    const uInt32 percentNow = static_cast<uInt32>(std::min((100 * cycles) /
      cyclesTarget, static_cast<uInt64>(100)));
    updateProgress(percent, percentNow);

    percent = percentNow;
  }

  const double realtimeUsed = duration_cast<duration<double>>(high_resolution_clock::now () - tp).count();

  if (dispatchResult.getStatus() != DispatchResult::Status::ok) {
    cout << "\nERROR: emulation failed after " << cycles << " cycles";
    return false;
  }

  (cout << "100%" << '\n').flush();
  cout << "real time: " << realtimeUsed << " seconds\n";

  return true;
}
