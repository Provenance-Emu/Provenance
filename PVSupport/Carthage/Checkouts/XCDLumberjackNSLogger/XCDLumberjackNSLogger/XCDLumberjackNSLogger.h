//
//  Copyright (c) 2015 Cédric Luthi. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>
#import <NSLogger/LoggerClient.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  The `XCDLumberjackNSLogger` class implements a [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) logger which sends logs to [NSLogger](https://github.com/fpillet/NSLogger).
 *
 *  `XCDLumberjackNSLogger` does not support log formatters, i.e. setting the `logFormatter` property has no effect.
 */
@interface XCDLumberjackNSLogger : NSObject <DDLogger>

/**
 *  ------------------------------
 *  @name Binding to User Defaults
 *  ------------------------------
 */

/**
 *  Automatically synchronize a single instance of a XCDLumberjackNSLogger to a bonjour service name stored in the standard user defaults.
 *
 *  @param userDefaultsKey      The user defaults key that contains the NSLogger bonjour service name
 *  @param configurationHandler A block which is called just before the managed logger is added to the CocoaLumberjack loggers. Configure the logger in this handler, you can set its <tags> for example. The return value is the level at which the managed logger will be added. Pass `nil` if you do not need any special configuration.
 *
 *  @discussion The managed XCDLumberjackNSLogger instance is removed from the CocoaLumberjack loggers when the user defaults value becomes nil or the empty string. A new XCDLumberjackNSLogger instance is added back when the user defaults value becomes a valid service name.
 *
 *  @warning This method must be called only once.
 */
+ (void) bindToBonjourServiceNameUserDefaultsKey:(NSString *)userDefaultsKey configurationHandler:(nullable DDLogLevel (^)(XCDLumberjackNSLogger *logger))configurationHandler;

/**
 *  ------------------
 *  @name Initializing
 *  ------------------
 */

/**
 *  Initializes a logger with the specified bonjour service name.
 *
 *  @param bonjourServiceName The bonjour service name of the destination NSLogger desktop viewer. The bonjour service name may be nil.
 *
 *  @discussion Providing a bonjour service name is useful if you are several developers on the same network using NSLogger. If you are the only developer using NSLogger, you can pass nil or simply use the standard `init` method instead.
 *
 *  @return A logger with the specified bonjour service name.
 */
- (instancetype) initWithBonjourServiceName:(NSString * _Nullable)bonjourServiceName NS_DESIGNATED_INITIALIZER;

/**
 *  -------------------------------------
 *  @name Accessing the underlying logger
 *  -------------------------------------
 */

/**
 *  The underlying NSLogger struct.
 *
 *  @discussion Use the underlying logger if you need fine-grained control. For example, you may want to call `LoggerSetViewerHost(lubmerjackNSLogger.logger, host, port)` if you are in a Bonjour-hostile network. You may also use this property to tweak the logger options with the `LoggerSetOptions` function.
 */
@property (readonly) Logger *logger;

/**
 *  ----------------------------------
 *  @name Translating contexts to tags
 *  ----------------------------------
 */

/**
 *  This property defines a relation between CocoaLumberjack contexts and NSLogger tags. The keys must be `NSNumber` objects representing CocoaLumberjack contexts and the values must be `NSString` objects corresponding to NSLogger tags.
 *
 *  @discussion Framework authors are [encouraged to choose a context](https://github.com/CocoaLumberjack/CocoaLumberjack/blob/8adde11d0b16843cb45b81dc9b60d1430eb9b538/Documentation/CustomContext.md#example-2) to allow application developers to easily manage the log statements coming from their framework.
 *  Unfortunately, a context is an NSInteger which is not appropriate for displaying in NSLogger. Use this property to translate unintelligible contexts into readable tags.
 *
 *  For example, CocoaHTTPServer [defines a context](https://github.com/robbiehanson/CocoaHTTPServer/blob/52b2a64e9cbdb5f09cc915814a5fb68a45dd3707/Core/HTTPLogging.h#L55) of 80. In order to translate it to a `CocoaHTTPServer` tag, use  `lubmerjackNSLogger.tags = @{ @80 : @"CocoaHTTPServer" };`
 */
@property (copy, nullable) NSDictionary *tags;

@end

NS_ASSUME_NONNULL_END
