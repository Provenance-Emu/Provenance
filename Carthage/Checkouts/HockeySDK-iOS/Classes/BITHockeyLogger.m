#import "BITHockeyLoggerPrivate.h"
#import "HockeySDK.h"

@implementation BITHockeyLogger

static BITLogLevel _currentLogLevel = BITLogLevelWarning;
static BITLogHandler currentLogHandler;

BITLogHandler const defaultLogHandler = ^(BITLogMessageProvider messageProvider, BITLogLevel logLevel, const char __unused *file, const char *function, uint line) {
  if (messageProvider) {
    if (_currentLogLevel < logLevel) {
      return;
    }
    NSString *functionString = [NSString stringWithUTF8String:function];
    NSLog((@"[HockeySDK] %@/%d %@"), functionString, line, messageProvider());
  }
};


+ (void)initialize {
  currentLogHandler = defaultLogHandler;
}

+ (BITLogLevel)currentLogLevel {
  return _currentLogLevel;
}

+ (void)setCurrentLogLevel:(BITLogLevel)currentLogLevel {
  _currentLogLevel = currentLogLevel;
}

+ (void)setLogHandler:(BITLogHandler)logHandler {
  currentLogHandler = logHandler;
}

+ (void)logMessage:(BITLogMessageProvider)messageProvider level:(BITLogLevel)loglevel file:(const char *)file function:(const char *)function line:(uint)line {
  if (currentLogHandler) {
    currentLogHandler(messageProvider, loglevel, file, function, line);
  }
}

@end
