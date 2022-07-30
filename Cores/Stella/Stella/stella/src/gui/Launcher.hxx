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

#ifndef LAUNCHER_HXX
#define LAUNCHER_HXX

class Properties;
class OSystem;
class FSNode;

#include "Rect.hxx"
#include "FrameBufferConstants.hxx"
#include "DialogContainer.hxx"

/**
  The base dialog for the ROM launcher in Stella.

  @author  Stephen Anthony
*/
class Launcher : public DialogContainer
{
  public:
    /**
      Create a new menu stack
    */
    explicit Launcher(OSystem& osystem);
    ~Launcher() override;

    /**
      Initialize the video subsystem wrt this class.
    */
    FBInitStatus initializeVideo();

    /**
      Wrapper for LauncherDialog::selectedRom() method.
    */
    const string& selectedRom();

    /**
      Wrapper for LauncherDialog::selectedRomMD5() method.
    */
    const string& selectedRomMD5();

    /**
      Wrapper for LauncherDialog::currentDir() method.
    */
    const FSNode& currentDir() const;

    /**
      Wrapper for LauncherDialog::reload() method.
    */
    void reload();

    /**
      Wrapper for LauncherDialog::quit() method.
    */
    void quit();

    /**
      Return (and possibly create) the bottom-most dialog of this container.
    */
    Dialog* baseDialog() override;

  private:
    Dialog* myBaseDialog{nullptr};

    // The dimensions of this dialog
    Common::Size mySize;

  private:
    // Following constructors and assignment operators not supported
    Launcher() = delete;
    Launcher(const Launcher&) = delete;
    Launcher(Launcher&&) = delete;
    Launcher& operator=(const Launcher&) = delete;
    Launcher& operator=(Launcher&&) = delete;
};

#endif
