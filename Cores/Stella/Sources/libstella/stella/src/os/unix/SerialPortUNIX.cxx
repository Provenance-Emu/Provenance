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

#include <fcntl.h>
#include <unistd.h>
#include <sys/termios.h>
#include <sys/ioctl.h>
#include <cstring>

#include "FSNode.hxx"
#include "SerialPortUNIX.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SerialPortUNIX::~SerialPortUNIX()
{
  if(myHandle)
  {
    close(myHandle);
    myHandle = 0;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SerialPortUNIX::openPort(const string& device)
{
  myHandle = open(device.c_str(), O_RDWR | O_NOCTTY | O_NONBLOCK);
  if(myHandle <= 0)
    return false;

  // Clear buffers, then open the device in nonblocking mode
  tcflush(myHandle, TCOFLUSH);
  tcflush(myHandle, TCIFLUSH);
  fcntl(myHandle, F_SETFL, FNDELAY);

  struct termios termios;
  memset(&termios, 0, sizeof(struct termios));

  termios.c_cflag = CREAD | CLOCAL;
  termios.c_cflag |= B19200;
  termios.c_cflag |= CS8;
  tcflush(myHandle, TCIFLUSH);
  tcsetattr(myHandle, TCSANOW, &termios);

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SerialPortUNIX::readByte(uInt8& data)
{
  if(myHandle)
    return read(myHandle, &data, 1) == 1;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SerialPortUNIX::writeByte(uInt8 data)
{
  if(myHandle)
    return write(myHandle, &data, 1) == 1;

  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SerialPortUNIX::isCTS()
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
StringList SerialPortUNIX::portNames()
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
    return BSPF::startsWithIgnoreCase(node.getPath(), "/dev/ttyACM") ||
           BSPF::startsWithIgnoreCase(node.getPath(), "/dev/ttyUSB");
  };
  FSList portList;
  portList.reserve(5);

  const FSNode dev("/dev/");
  dev.getChildren(portList, FSNode::ListMode::All, filter, false);

  // Add only those that can be opened
  for(const auto& port: portList)
    if(isPortValid(port.getPath()))
      ports.emplace_back(port.getPath());

  return ports;
}
