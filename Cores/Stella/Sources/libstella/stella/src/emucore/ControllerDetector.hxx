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

#ifndef CONTROLLER_DETECTOR_HXX
#define CONTROLLER_DETECTOR_HXX

class Settings;

#include "Control.hxx"

/**
  Auto-detect controller type by matching determining pattern.

  @author  Thomas Jentzsch
*/

class ControllerDetector
{
  public:
    /**
      Detects the controller type at the given port if no controller is provided.

      @param image       A reference to the ROM image
      @param size        The size of the ROM image
      @param type        The provided controller type of the ROM image
      @param port        The port to be checked
      @param settings    A reference to the various settings (read-only)
      @param isQuadTari  If true, try to detect the QuadTari's controllers
      @return   The detected controller type
    */
    static Controller::Type detectType(const ByteBuffer& image, size_t size,
        const Controller::Type type, const Controller::Jack port,
        const Settings& settings, bool isQuadTari = false);

    /**
      Detects the controller type at the given port if no controller is provided
      and returns its name.

      @param image       A reference to the ROM image
      @param size        The size of the ROM image
      @param type        The provided controller type of the ROM image
      @param port        The port to be checked
      @param settings    A reference to the various settings (read-only)
      @param isQuadTari  If true, try to detect the QuadTari's controllers

      @return   The (detected) controller name
    */
    static string detectName(const ByteBuffer& image, size_t size,
        const Controller::Type type, const Controller::Jack port,
        const Settings& settings, bool isQuadTari = false);

  private:
    /**
      Detects the controller type at the given port.

      @param image       A reference to the ROM image
      @param size        The size of the ROM image
      @param port        The port to be checked
      @param settings    A reference to the various settings (read-only)
      @param isQuadTari  If true, try to detect the QuadTari's controllers

      @return   The detected controller type
    */
    static Controller::Type autodetectPort(const ByteBuffer& image, size_t size,
        Controller::Jack port, const Settings& settings, bool isQuadTari);

    /**
      Search the image for the specified byte signature.

      @param image      A pointer to the ROM image
      @param imagesize  The size of the ROM image
      @param signature  The byte sequence to search for
      @param sigsize    The number of bytes in the signature

      @return  True if the signature was found, else false
    */
    static bool searchForBytes(const ByteBuffer& image, size_t imagesize,
                               const uInt8* signature, uInt32 sigsize);

    // Returns true if the port's joystick button access code is found.
    static bool usesJoystickButton(const ByteBuffer& image, size_t size,
                                   Controller::Jack port);

    // Returns true if joystick direction access code is found.
    static bool usesJoystickDirections(const ByteBuffer& image, size_t size);

    // Returns true if the port's keyboard access code is found.
    static bool usesKeyboard(const ByteBuffer& image, size_t size,
                             Controller::Jack port);

    // Returns true if the port's 2nd Genesis button access code is found.
    static bool usesGenesisButton(const ByteBuffer& image, size_t size,
                                  Controller::Jack port);

    // Returns true if the port's paddle button access code is found.
    static bool usesPaddle(const ByteBuffer& image, size_t size,
                           Controller::Jack port, const Settings& settings);

    // Returns true if a Trak-Ball table is found.
    static bool isProbablyTrakBall(const ByteBuffer& image, size_t size);

    // Returns true if an Atari Mouse table is found.
    static bool isProbablyAtariMouse(const ByteBuffer& image, size_t size);

    // Returns true if an Amiga Mouse table is found.
    static bool isProbablyAmigaMouse(const ByteBuffer& image, size_t size);

    // Returns true if a SaveKey code pattern is found.
    static bool isProbablySaveKey(const ByteBuffer& image, size_t size,
                                  Controller::Jack port);

    // Returns true if a Lightgun code pattern is found
    static bool isProbablyLightGun(const ByteBuffer& image, size_t size,
                                   Controller::Jack port);

    // Returns true if a QuadTari code pattern is found.
    static bool isProbablyQuadTari(const ByteBuffer& image, size_t size,
                                   Controller::Jack port);

    // Returns true if a Kid Vid code pattern is found.
    static bool isProbablyKidVid(const ByteBuffer& image, size_t size,
                                   Controller::Jack port);
  private:
    // Following constructors and assignment operators not supported
    ControllerDetector() = delete;
    ControllerDetector(const ControllerDetector&) = delete;
    ControllerDetector(ControllerDetector&&) = delete;
    ControllerDetector& operator=(const ControllerDetector&) = delete;
    ControllerDetector& operator=(ControllerDetector&&) = delete;
};

#endif
