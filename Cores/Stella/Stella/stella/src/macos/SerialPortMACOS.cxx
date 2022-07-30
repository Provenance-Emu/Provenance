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

#include <stdio.h>
#include <fcntl.h>
#include <sys/errno.h>
#include <sys/termios.h>
#include <sys/types.h>
#include <sys/time.h>
#include <unistd.h>
#include <sys/filio.h>
#include <sys/ioctl.h>

#include "FSNode.hxx"
#include "SerialPortMACOS.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SerialPortMACOS::SerialPortMACOS()
  : SerialPort()
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SerialPortMACOS::~SerialPortMACOS()
{
  if(myHandle)
  {
    close(myHandle);
    myHandle = 0;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SerialPortMACOS::openPort(const string& device)
{
  myHandle = open(device.c_str(), O_RDWR | O_NOCTTY | O_NONBLOCK);
  if(myHandle <= 0)
    return false;

  struct termios termios;
  tcgetattr(myHandle, &termios);
  memset(&termios, 0, sizeof(struct termios));
  cfmakeraw(&termios);
  cfsetspeed(&termios, 19200);       // change to 19200 baud
  termios.c_cflag = CREAD | CLOCAL;  // turn on READ and ignore modem control lines
  termios.c_cflag |= CS8;            // 8 bit
  termios.c_cflag |= CDTR_IFLOW;     // inbound DTR
  tcsetattr(myHandle, TCSANOW, &termios);

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SerialPortMACOS::readByte(uInt8& data)
{
  if(myHandle)
    return read(myHandle, &data, 1) == 1;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SerialPortMACOS::writeByte(uInt8 data)
{
  if(myHandle)
    return write(myHandle, &data, 1) == 1;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SerialPortMACOS::isCTS()
{
  if(myHandle)
  {
    int status = 0;
    ioctl(myHandle, TIOCMGET, &status);
    return status & TIOCM_CTS;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StringList SerialPortMACOS::portNames()
{
  StringList ports;

  // Check if port is valid; for now that means if it can be opened
  // Eventually we may extend this to do more intensive checks
  const auto isPortValid = [](const string& port) {
    const int handle = open(port.c_str(), O_RDWR | O_NOCTTY | O_NONBLOCK);
    if(handle > 0)  close(handle);
    return handle > 0;
  };

  // Get all possible devices in the '/dev' directory
  const FSNode::NameFilter filter = [](const FSNode& node) {
    return BSPF::startsWithIgnoreCase(node.getPath(), "/dev/cu.usb");
  };
  FSList portList;
  portList.reserve(5);

  FSNode dev("/dev/");
  dev.getChildren(portList, FSNode::ListMode::All, filter, false);

  // Add only those that can be opened
  for(const auto& port: portList)
    if(isPortValid(port.getPath()))
      ports.emplace_back(port.getPath());

  return ports;
}
