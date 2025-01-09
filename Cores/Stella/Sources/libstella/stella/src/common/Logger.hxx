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

#ifndef LOGGER_HXX
#define LOGGER_HXX

#include <functional>
#include <mutex>

#include "bspf.hxx"
#undef DEBUG

class Logger {

  public:

    enum class Level {
      ERR = 0, // cannot use ERROR???
      INFO = 1,
      DEBUG = 2,
      ALWAYS = 3,
      MIN = ERR,
      MAX = DEBUG
    };

  public:

    static Logger& instance();

    static void log(string_view message, Level level = Level::ALWAYS);

    static void error(string_view message);

    static void info(string_view message);

    static void debug(string_view message);

    void setLogParameters(int logLevel, bool logToConsole);
    void setLogParameters(Level logLevel, bool logToConsole);

    const string& logMessages() const { return myLogMessages; }

  protected:
    Logger() = default;

  private:
    int myLogLevel{static_cast<int>(Level::MAX)};
    bool myLogToConsole{true};

    // The list of log messages
    string myLogMessages;

    std::mutex mutex;

  private:
    void logMessage(string_view message, Level level);

    Logger(const Logger&) = delete;
    Logger(Logger&&) = delete;
    Logger& operator=(const Logger&) = delete;
    Logger& operator=(const Logger&&) = delete;
};

#endif // LOGGER_HXX
