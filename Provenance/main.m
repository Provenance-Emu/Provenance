#import <Foundation/Foundation.h>
#import <Provenance-Swift.h>

int main(int argc, char *argv[]) {
   @autoreleasepool {
      return UIApplicationMain(argc, argv,
        NSStringFromClass([PVApplication class]),
        NSStringFromClass([PVAppDelegate class]));
   }
}
