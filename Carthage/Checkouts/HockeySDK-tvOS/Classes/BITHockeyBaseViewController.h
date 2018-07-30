#import <UIKit/UIKit.h>

@interface BITHockeyBaseViewController : UITableViewController

@property (nonatomic, readwrite) BOOL modalAnimated;

- (instancetype)initWithModalStyle:(BOOL)modal;
- (instancetype)initWithStyle:(UITableViewStyle)style modal:(BOOL)modal;

@end
