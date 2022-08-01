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

#include "Windows.hxx"
#include "SerialPortWINDOWS.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SerialPortWINDOWS::SerialPortWINDOWS()
  : SerialPort()
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
SerialPortWINDOWS::~SerialPortWINDOWS()
{
  if(myHandle != INVALID_HANDLE_VALUE)
  {
    CloseHandle(myHandle);
    myHandle = INVALID_HANDLE_VALUE;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SerialPortWINDOWS::openPort(const string& device)
{
  if(myHandle == INVALID_HANDLE_VALUE)
  {
    myHandle = CreateFile(device.c_str(), GENERIC_READ|GENERIC_WRITE, 0,
                          NULL, OPEN_EXISTING, 0, NULL);

    if(myHandle != INVALID_HANDLE_VALUE)
    {
      DCB dcb;

      FillMemory(&dcb, sizeof(dcb), 0);
      dcb.DCBlength = sizeof(dcb);
      if(!BuildCommDCB("19200,n,8,1", &dcb))
      {
        CloseHandle(myHandle);
        myHandle = INVALID_HANDLE_VALUE;
        return false;
      }

      memset(&dcb, 0, sizeof(DCB));
      dcb.BaudRate = CBR_19200;
      dcb.ByteSize = 8;
      dcb.Parity = NOPARITY;
      dcb.StopBits = ONESTOPBIT;
      SetCommState(myHandle, &dcb);

      COMMTIMEOUTS commtimeouts;
      commtimeouts.ReadIntervalTimeout = MAXDWORD;
      commtimeouts.ReadTotalTimeoutMultiplier = 0;
      commtimeouts.ReadTotalTimeoutConstant = 1;
      commtimeouts.WriteTotalTimeoutMultiplier = 0;
      commtimeouts.WriteTotalTimeoutConstant = 0;
      SetCommTimeouts(myHandle, &commtimeouts);
    }
    else
      return false;
  }
  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SerialPortWINDOWS::readByte(uInt8& data)
{
  if(myHandle != INVALID_HANDLE_VALUE)
  {
    DWORD read;
    ReadFile(myHandle, &data, 1, &read, NULL);
    return read == 1;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SerialPortWINDOWS::writeByte(uInt8 data)
{
  if(myHandle != INVALID_HANDLE_VALUE)
  {
    DWORD written;
    WriteFile(myHandle, &data, 1, &written, NULL);
    return written == 1;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool SerialPortWINDOWS::isCTS()
{
  if(myHandle != INVALID_HANDLE_VALUE)
  {
    DWORD modemStat;
    GetCommModemStatus(myHandle, &modemStat);
    return modemStat & MS_CTS_ON;
  }
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
StringList SerialPortWINDOWS::portNames()
{
  StringList ports;

  HKEY hKey = NULL;
  LSTATUS result = RegOpenKeyExW(HKEY_LOCAL_MACHINE,
    L"HARDWARE\\DEVICEMAP\\SERIALCOMM", 0, KEY_READ, &hKey);
  if (result == ERROR_SUCCESS)
  {
    TCHAR deviceName[2048], friendlyName[32];
    DWORD numValues = 0;

    result = RegQueryInfoKey(hKey, NULL, NULL, NULL, NULL, NULL, NULL,
      &numValues, NULL, NULL, NULL, NULL);
    if (result == ERROR_SUCCESS)
    {
      for (DWORD i = 0; i < numValues; ++i)
      {
        // must be reset to work in a loop!
        DWORD type = 0;
        DWORD deviceNameLen = 2047;
        DWORD friendlyNameLen = 31;

        result = RegEnumValue(hKey, i, deviceName, &deviceNameLen,
          NULL, &type, (LPBYTE)friendlyName, &friendlyNameLen);

        if (result == ERROR_SUCCESS && type == REG_SZ)
          ports.emplace_back(friendlyName);
      }
    }
  }
  RegCloseKey(hKey);

  std::sort(ports.begin(), ports.end(),
    [](const std::string& a, const std::string& b)
  {
    return a < b;
  }
  );

  return ports;
}
