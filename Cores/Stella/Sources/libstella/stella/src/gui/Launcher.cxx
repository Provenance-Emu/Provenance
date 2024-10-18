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

#include "LauncherDialog.hxx"
#include "Version.hxx"
#include "OSystem.hxx"
#include "Settings.hxx"
#include "FSNode.hxx"
#include "FrameBuffer.hxx"
#include "bspf.hxx"

#include "Launcher.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Launcher::Launcher(OSystem& osystem)
  : DialogContainer(osystem),
    mySize{myOSystem.settings().getSize("launcherres")}
{
  const Common::Size& d = myOSystem.frameBuffer().desktopSize(BufferType::Launcher);
  const double overscan = 1 - myOSystem.settings().getInt("tia.fs_overscan") / 100.0;

  // The launcher dialog is resizable, within certain bounds
  // We check those bounds now
  mySize.clamp(FBMinimum::Width, d.w, FBMinimum::Height, d.h);
  // Do not include overscan when launcher saving size
  myOSystem.settings().setValue("launcherres", mySize);
  // Now make overscan effective
  mySize.w = std::min(mySize.w, static_cast<uInt32>(d.w * overscan));
  mySize.h = std::min(mySize.h, static_cast<uInt32>(d.h * overscan));

  myBaseDialog = new LauncherDialog(myOSystem, *this, 0, 0, mySize.w, mySize.h);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Launcher::~Launcher()
{
  delete myBaseDialog;  myBaseDialog = nullptr;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FBInitStatus Launcher::initializeVideo()
{
  const string title = string("Stella ") + STELLA_VERSION;
  return myOSystem.frameBuffer().createDisplay(
      title, BufferType::Launcher, mySize
  );
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const string& Launcher::selectedRom()
{
  return (static_cast<LauncherDialog*>(myBaseDialog))->selectedRom();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const string& Launcher::selectedRomMD5()
{
  return (static_cast<LauncherDialog*>(myBaseDialog))->selectedRomMD5();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
const FSNode& Launcher::currentDir() const
{
  return (static_cast<LauncherDialog*>(myBaseDialog))->currentDir();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Launcher::reload()
{
  (static_cast<LauncherDialog*>(myBaseDialog))->reload();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Launcher::quit()
{
  (static_cast<LauncherDialog*>(myBaseDialog))->quit();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Dialog* Launcher::baseDialog()
{
  return myBaseDialog;
}
