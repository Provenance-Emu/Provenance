#import <PVRetroArch/PVRetroArch.h>
#import <PVRetroArch/PVRetroArchCoreBridge.h>
#import <PVRetroArch/PVRetroArch-Swift.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/// Test runner application delegate for RetroArch core testing
@interface TestRunner : UIApplication<UIApplicationDelegate>

/// Main window of the application
@property (nonatomic, strong) UIWindow *window;

/// Main view of the application
@property (nonatomic, strong) UIView *view;

@end

/// Global core instance
static PVRetroArchCoreBridge *core;

@implementation TestRunner

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"Launching TestRunner");

    [self setDelegate:self];

    // Setup window
    UIWindowScene *scene = (UIWindowScene *)[[[UIApplication sharedApplication] connectedScenes] anyObject];
    self.window = [[UIWindow alloc] initWithWindowScene:scene];

    // Create and configure view controller
    UIViewController *viewController = [[UIViewController alloc] init];
    viewController.view.backgroundColor = [UIColor blackColor];

    // Set root view controller
    self.window.rootViewController = viewController;
    self.view.translatesAutoresizingMaskIntoConstraints = true;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view = viewController.view;
    self.view.frame = self.window.bounds;

    // Make window visible
    [self.window makeKeyAndVisible];

    // Configure core
    core = [PVRetroArchCoreBridge new];
    [core setRootView:YES];

    // Start emulation on a background thread
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Starting emulation on main thread");
        [core startEmulation];
    });

    return YES;
}

- (void)sendEvent:(UIEvent *)event {
    if (core != nil) {
        [core sendEvent:event];
    }
    [super sendEvent:event];
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv,
                               NSStringFromClass([TestRunner class]),
                               NSStringFromClass([TestRunner class]));
    }
}
