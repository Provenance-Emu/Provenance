## Introduction

HockeySDK lets the user decide wether to send a crash report or lets the developer send crash reports automatically without user interaction. In addition it is possible to attach more data like logs, a binary, or the users name, email or a user ID if this is already known.

Starting with HockeySDK version 3.6 it is possible to customize this even further and implement your own flow to e.g. ask the user for more details about what happened or his name and email address if your app doesn't know that yet.

The following example shows how this could be implemented. We'll present a custom UIAlertView asking the user for more details and attaching that to the crash report.

## HowTo

1. Setup the SDK
2. Configure HockeySDK to use your custom alertview handler using the `[[BITHockeyManager sharedHockeyManager].crashManager setAlertViewHandler:(BITCustomAlertViewHandler)alertViewHandler;` method in your AppDelegate.
3. Implement your handler in a way that it calls `[[BITHockeyManager sharedHockeyManager].crashManagerhandleUserInput:(BITCrashManagerUserInput)userInput withUserProvidedMetaData:(BITCrashMetaData *)userProvidedMetaData]` with the input provided by the user.
4. Dismiss your custom view.

## Example

**Objective-C**

```objc

@implementation BITAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [self.window makeKeyAndVisible];

  [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"APP_IDENTIFIER" delegate:nil];
	
  // optionally enable logging to get more information about states.
  [BITHockeyManager sharedHockeyManager].logLevel = BITLogLevelVerbose;

  [[BITHockeyManager sharedHockeyManager].crashManager setAlertViewHandler:^() {
    NSString *exceptionReason = [[BITHockeyManager sharedHockeyManager].crashManager lastSessionCrashDetails].exceptionReason;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Oh no! The App crashed"
                                                                             message:@"We would like to send a crash report to the developers."
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    if (exceptionReason) {
      alertController.message = [NSString stringWithFormat:@"%@ Please enter a short description of what happened:", alertController.message];
      [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Description";
        textField.keyboardType = UIKeyboardTypeDefault;
      }];
    }
    [alertController addAction:[UIAlertAction actionWithTitle:@"Don't send"
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction __unused *action) {
                                                        [[BITHockeyManager sharedHockeyManager].crashManager
                                                                     handleUserInput:BITCrashManagerUserInputDontSend
                                                            withUserProvidedMetaData:nil];
                                                      }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Send"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction __unused *action) {
                                                        BITCrashMetaData *crashMetaData = [BITCrashMetaData new];
                                                        if (exceptionReason) {
                                                          crashMetaData.userProvidedDescription = alertController.textFields[0].text;
                                                        }
                                                        [[BITHockeyManager sharedHockeyManager].crashManager
                                                                     handleUserInput:BITCrashManagerUserInputSend
                                                            withUserProvidedMetaData:crashMetaData];
c                                                      }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Always send"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction __unused *action) {
                                                        BITCrashMetaData *crashMetaData = [BITCrashMetaData new];
                                                        if (exceptionReason) {
                                                          crashMetaData.userProvidedDescription = alertController.textFields[0].text;
                                                        }
                                                        [[BITHockeyManager sharedHockeyManager].crashManager
                                                                     handleUserInput:BITCrashManagerUserInputAlwaysSend
                                                            withUserProvidedMetaData:crashMetaData];
                                                      }]];

    [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
  }];

  return YES;
}

@end
```

**Swift**

```swift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    window?.makeKeyAndVisible()
    
    BITHockeyManager.shared().configure(withIdentifier: "APP_IDENTIFIER")
    
    // optionally enable logging to get more information about states.
    BITHockeyManager.shared().logLevel = BITLogLevel.verbose
    
    BITHockeyManager.shared().crashManager.setAlertViewHandler {
      let exceptionReason = BITHockeyManager.shared().crashManager.lastSessionCrashDetails.exceptionReason
      let alertController = UIAlertController(title: "Oh no! The App crashed", message: "We would like to send a crash report to the developers.", preferredStyle: .alert)
      if exceptionReason != nil {
        alertController.message = alertController.message! + " Please enter a short description of what happened:"
        alertController.addTextField(configurationHandler: { (textField) in
          textField.placeholder = "Description"
          textField.keyboardType = .default
        })
      }
      alertController.addAction(UIAlertAction(title: "Don't send", style: .cancel, handler: { (action) in
        BITHockeyManager.shared().crashManager.handle(BITCrashManagerUserInput.dontSend, withUserProvidedMetaData: nil)
      }))
      alertController.addAction(UIAlertAction(title: "Send", style: .default, handler: { (action) in
        let crashMetaData = BITCrashMetaData()
        crashMetaData.userProvidedDescription = alertController.textFields?[0].text
        BITHockeyManager.shared().crashManager.handle(BITCrashManagerUserInput.send, withUserProvidedMetaData: crashMetaData)
      }))
      alertController.addAction(UIAlertAction(title: "Always send", style: .default, handler: { (action) in
        let crashMetaData = BITCrashMetaData()
        crashMetaData.userProvidedDescription = alertController.textFields?[0].text
        BITHockeyManager.shared().crashManager.handle(BITCrashManagerUserInput.alwaysSend, withUserProvidedMetaData: crashMetaData)
      }))
      self.window?.rootViewController?.present(alertController, animated: true)
    }
    
    return true
  }
}

```
