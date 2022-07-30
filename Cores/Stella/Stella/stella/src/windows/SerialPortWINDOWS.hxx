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

#ifndef SERIALPORT_WINDOWS_HXX
#define SERIALPORT_WINDOWS_HXX

#include "Windows.hxx"
#include "SerialPort.hxx"

/**
  Implement reading and writing from a serial port under Windows systems.
*/
class SerialPortWINDOWS : public SerialPort
{
  public:
    SerialPortWINDOWS();
    ~SerialPortWINDOWS() override;

    /**
      Open the given serial port with the specified attributes.

      @param device  The name of the port
      @return  False on any errors, else true
    */
    bool openPort(const string& device) override;

    /**
      Read a byte from the serial port.

      @param data  Destination for the byte read from the port
      @return  True if a byte was read, else false
    */
    bool readByte(uInt8& data) override;

    /**
      Write a byte to the serial port.

      @param data  The byte to write to the port
      @return  True if a byte was written, else false
    */
    bool writeByte(uInt8 data) override;

    /**
      Test for 'Clear To Send' enabled.  By default, assume it's always
      OK to send more data.

      @return  True if CTS signal enabled, else false
    */
    bool isCTS() override;

    /**
      Get all valid serial ports detected on this system.

      @return  The (possibly empty) list of detected serial ports
    */
    StringList portNames() override;

  private:
    // Handle to serial port
    HANDLE myHandle{INVALID_HANDLE_VALUE};

  private:
    // Following constructors and assignment operators not supported
    SerialPortWINDOWS(const SerialPortWINDOWS&) = delete;
    SerialPortWINDOWS(SerialPortWINDOWS&&) = delete;
    SerialPortWINDOWS& operator=(const SerialPortWINDOWS&) = delete;
    SerialPortWINDOWS& operator=(SerialPortWINDOWS&&) = delete;
};

#endif
