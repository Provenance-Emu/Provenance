#import <PVRetroArch/PVRetroArchCore.h>
#import <PVRetroArch/RetroArch-Swift.h>
#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <UIKit/UIKit.h>
@interface TestRunner : UIApplication<UIApplicationDelegate>
@property (nonatomic) UIWindow* window;
@property (nonatomic) UIView* view;
@end
PVRetroArchCore *core;
@implementation TestRunner
- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    NSLog(@"Launching TestRunner\n");
    [self setDelegate:self];
    CGRect bounds=[[UIScreen mainScreen] bounds];
    self.window = [[UIWindow alloc] initWithFrame:bounds];
    [self.window makeKeyAndVisible];
    UIViewController *view_controller=[[UIViewController alloc] initWithNibName:nil bundle:nil];
    view_controller.view.frame=bounds;
    self.view=view_controller.view;
    [self.window setRootViewController:view_controller];
    core=[PVRetroArchCore alloc];
    [core setRootView:true];
    [core startEmulation];
}
- (void)sendEvent:(UIEvent *)event
{
    if (core != NULL)
        [core sendEvent:event];
    [super sendEvent:event];
}
@end

int main(int argc, char *argv[])
{
   @autoreleasepool {
      return UIApplicationMain(argc, argv,
        NSStringFromClass([TestRunner class]),
        NSStringFromClass([TestRunner class]));
   }
}
