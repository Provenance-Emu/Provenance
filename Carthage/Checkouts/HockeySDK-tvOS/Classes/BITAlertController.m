#import "BITAlertController.h"
#import <UIKit/UIWindow.h>
#import <UIKit/UIScreen.h>

static char *const BITAlertsDispatchQueue = "net.hockeyapp.alertsQueue";

@implementation BITAlertAction

+ (instancetype)defaultActionWithTitle:(NSString *)title handler:(void (^)(UIAlertAction *))handler {
  return [self actionWithTitle:title style:UIAlertActionStyleDefault handler:handler];
}

+ (instancetype)cancelActionWithTitle:(NSString *)title handler:(void (^)(UIAlertAction *))handler {
  return [self actionWithTitle:title style:UIAlertActionStyleCancel handler:handler];
}

+ (instancetype)destructiveActionWithTitle:(NSString *)title handler:(void (^)(UIAlertAction *))handler {
  return [self actionWithTitle:title style:UIAlertActionStyleDestructive handler:handler];
}

@end

@interface BITAlertController ()

@end

@implementation BITAlertController

static UIWindow *window;
static BOOL alertIsBeingPresented;
static NSMutableArray *alertsToBePresented;
static dispatch_queue_t alertsQueue;

+ (void)initialize {
  alertIsBeingPresented = NO;
  alertsToBePresented = @[].mutableCopy;
  alertsQueue = dispatch_queue_create(BITAlertsDispatchQueue, DISPATCH_QUEUE_CONCURRENT);
  
  UIViewController *emptyViewController = [UIViewController new];
  [emptyViewController.view setBackgroundColor:[UIColor clearColor]];
  
  window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  window.rootViewController = emptyViewController;
  window.backgroundColor = [UIColor clearColor];
  window.windowLevel = UIWindowLevelAlert + 1;
}

+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message {
  return [self alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
  alertIsBeingPresented = NO;
  [BITAlertController presentNextPendingAlertController];
}

- (void)addDefaultActionWithTitle:(NSString *)title handler:(void (^)(UIAlertAction *))handler {
  [self addAction:[BITAlertAction defaultActionWithTitle:title handler:handler]];
}

- (void)addCancelActionWithTitle:(NSString *)title handler:(void (^)(UIAlertAction *))handler {
  [self addAction:[BITAlertAction cancelActionWithTitle:title handler:handler]];
}

- (void)addDestructiveActionWithTitle:(NSString *)title handler:(void (^)(UIAlertAction *))handler {
  [self addAction:[BITAlertAction destructiveActionWithTitle:title handler:handler]];
}

- (void)show {
  [self showAnimated:YES];
}

- (void)showAnimated:(BOOL)animated {
  dispatch_barrier_async(alertsQueue, ^{
    [alertsToBePresented addObject:self];
  });
  [BITAlertController presentNextPendingAlertController];
}

+ (void)presentNextPendingAlertController {
  if (alertIsBeingPresented) {
    return;
  }
  BITAlertController *__block nextAlert;
  dispatch_sync(alertsQueue, ^{
    nextAlert = alertsToBePresented.firstObject;
  });
  if (nextAlert) {
    alertIsBeingPresented = YES;
    dispatch_barrier_async(alertsQueue, ^{
      [alertsToBePresented removeObjectAtIndex:0];
    });
    dispatch_async(dispatch_get_main_queue(), ^{
      [window makeKeyAndVisible];
      [window.rootViewController presentViewController:nextAlert animated:YES completion:nil];
    });
  } else {
    window.hidden = YES;
    alertIsBeingPresented = NO;
  }
}

@end
