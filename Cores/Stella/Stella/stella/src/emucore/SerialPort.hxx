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

#ifndef SERIALPORT_HXX
#define SERIALPORT_HXX

#include "bspf.hxx"

/**
  This class provides an interface for a standard serial port.
  For now, this is used when connecting a real AtariVox device,
  and as such it always uses 19200, 8n1, no flow control.

  @author  Stephen Anthony
*/
class SerialPort
{
  public:
    SerialPort() = default;
    virtual ~SerialPort() = default;

    /**
      Open the given serial port with the specified attributes.

      @param device  The name of the port
      @return  False on any errors, else true
    */
    virtual bool openPort(const string& device) { return false; }

    /**
      Read a byte from the serial port.

      @param data  Destination for the byte read from the port
      @return  True if a byte was read, else false
    */
    virtual bool readByte(uInt8& data) { return false; }

    /**
      Write a byte to the serial port.

      @param data  The byte to write to the port
      @return  True if a byte was written, else false
    */
    virtual bool writeByte(uInt8 data) { return false; }

    /**
      Test for 'Clear To Send' enabled.  By default, assume it's always
      OK to send more data.

      @return  True if CTS signal enabled, else false
    */
    virtual bool isCTS() { return true; }

    /**
      Get all valid serial ports detected on this system.

      @return  The (possibly empty) list of detected serial ports
    */
    virtual StringList portNames() { return StringList{}; }

  private:
    // Following constructors and assignment operators not supported
    SerialPort(const SerialPort&) = delete;
    SerialPort(SerialPort&&) = delete;
    SerialPort& operator=(const SerialPort&) = delete;
    SerialPort& operator=(SerialPort&&) = delete;
};

#endif
