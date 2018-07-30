//
//  MarqueeLabelTableViewController.h
//  MarqueeLabelDemo
//
//  Created by Charles Powell on 3/25/16.
//
//

#import <UIKit/UIKit.h>
#import "MarqueeLabel.h"

@interface MLCell : UITableViewCell
@property (nonatomic, weak) IBOutlet MarqueeLabel *label;
@end

@interface MLHeader : UITableViewHeaderFooterView
@property (nonatomic, weak) IBOutlet UIView *border;
@end

@interface MarqueeLabelTableViewController : UITableViewController <UITableViewDataSource>

@property (nonatomic, strong) NSArray *strings;

@end
