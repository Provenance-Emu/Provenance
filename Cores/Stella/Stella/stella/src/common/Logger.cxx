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

#include "Logger.hxx"

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Logger& Logger::instance()
{
  static Logger loggerInstance;

  return loggerInstance;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Logger::log(const string& message, Level level)
{
  instance().logMessage(message, level);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Logger::error(const string& message)
{
  instance().logMessage(message, Level::ERR);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Logger::info(const string& message)
{
  instance().logMessage(message, Level::INFO);
}
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Logger::debug(const string& message)
{
  instance().logMessage(message, Level::DEBUG);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Logger::logMessage(const string& message, Level level)
{
  std::lock_guard<std::mutex> lock(mutex);

  if(level == Logger::Level::ERR)
  {
    cout << message << endl << std::flush;
    myLogMessages += message + "\n";
  }
  else if(static_cast<int>(level) <= myLogLevel ||
          level == Logger::Level::ALWAYS)
  {
    if(myLogToConsole)
      cout << message << endl << std::flush;
    myLogMessages += message + "\n";
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Logger::setLogParameters(int logLevel, bool logToConsole)
{
  if(logLevel >= static_cast<int>(Level::MIN) &&
     logLevel <= static_cast<int>(Level::MAX))
  {
    myLogLevel = logLevel;
    myLogToConsole = logToConsole;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void Logger::setLogParameters(Level logLevel, bool logToConsole)
{
  setLogParameters(static_cast<int>(logLevel), logToConsole);
}
