#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface BITHockeyHelper : NSObject

@end

/* NSString helpers */
NSString *bit_URLEncodedString(NSString *inputString);

NSString *bit_settingsDir(void);

BOOL bit_validateEmail(NSString *email);
NSString *bit_keychainHockeySDKServiceName(void);

NSComparisonResult bit_versionCompare(NSString *stringA, NSString *stringB);
NSString *bit_mainBundleIdentifier(void);
NSString *bit_encodeAppIdentifier(NSString *inputString);
NSString *bit_appIdentifierToGuid(NSString *appIdentifier);
NSString *bit_appName(NSString *placeHolderString);
NSString *bit_UUID(void);
NSString *bit_appAnonID(BOOL forceNewAnonID);
BOOL bit_isDebuggerAttached(void);
BOOL bit_isAppStoreReceiptSandbox(void);
BOOL bit_hasEmbeddedMobileProvision(void);
BOOL bit_isRunningInTestFlightEnvironment(void);
BOOL bit_isRunningInAppStoreEnvironment(void);

UIImage *bit_newWithContentsOfResolutionIndependentFile(NSString * path);
UIImage *bit_imageWithContentsOfResolutionIndependentFile(NSString * path);
UIImage *bit_imageNamed(NSString *imageName, NSString *bundleName);

/* Telemetry helper */
NSString *bit_utcDateString(NSDate *date);
NSString *bit_devicePlatform(void);
NSString *bit_devicePlatform(void);
NSString *bit_deviceType(void);
NSString *bit_osVersionBuild(void);
NSString *bit_osName(void);
NSString *bit_deviceLocale(void);
NSString *bit_deviceLanguage(void);
NSString *bit_screenSize(void);
NSString *bit_sdkVersion(void);
NSString *bit_appVersion(void);
