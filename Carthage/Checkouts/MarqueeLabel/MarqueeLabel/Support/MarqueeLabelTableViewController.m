//
//  MarqueeLabelTableViewController.m
//  MarqueeLabelDemo
//
//  Created by Charles Powell on 3/25/16.
//
//

#import "MarqueeLabelTableViewController.h"

@implementation MLCell
@end

@implementation MLHeader

@end

@implementation MarqueeLabelTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.strings = @[@"When shall we three meet again in thunder, lightning, or in rain? When the hurlyburly's done, When the battle 's lost and won.",
                     @"I have no spur to prick the sides of my intent, but only vaulting ambition, which o'erleaps itself, and falls on the other.",
                     @"Double, double toil and trouble; Fire burn, and cauldron bubble.",
                     @"By the pricking of my thumbs, Something wicked this way comes.",
                     @"My favorite things in life don't cost any money. It's really clear that the most precious resource we all have is time.",
                     @"Be a yardstick of quality. Some people aren't used to an environment where excellence is expected."];
    
    UIEdgeInsets tabBarInsets = UIEdgeInsetsMake(0, 0, CGRectGetHeight(self.tabBarController.tabBar.frame), 0);
    self.tableView.contentInset = tabBarInsets;
    tabBarInsets.top = 84;
    self.tableView.scrollIndicatorInsets = tabBarInsets;
    
    [self.tableView registerNib:[UINib nibWithNibName:@"MLHeader" bundle:nil] forHeaderFooterViewReuseIdentifier:@"MLHeader"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 30;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"MLHeader"];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 84;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MLCell *cell = (MLCell *)[tableView dequeueReusableCellWithIdentifier:@"MLCell" forIndexPath:indexPath];
    
    cell.label.text = self.strings[arc4random_uniform((int)self.strings.count)];
    cell.label.marqueeType = MLContinuous;
    cell.label.scrollDuration = 15.0;
    cell.label.animationCurve = UIViewAnimationOptionCurveEaseInOut;
    cell.label.fadeLength = 10.0f;
    cell.label.leadingBuffer = 14.0;
    
    // Labelize normally, to improve scrolling performance
    cell.label.labelize = YES;
    // Set background, to improve scrolling performance
    cell.label.backgroundColor = [UIColor whiteColor];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    MLCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    // De-labelize on selection
    cell.label.labelize = NO;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // Re-labelize all scrolling upon tableview scroll
    for (MLCell *cell in self.tableView.visibleCells) {
        cell.label.labelize = YES;
    }
    
    // Animate border
    MLHeader *header = (MLHeader *)[self.tableView headerViewForSection:0];
    [UIView animateWithDuration:0.2f animations:^{
        header.border.alpha = (scrollView.contentOffset.y > 1.0f ? 1.0f : 0.0f);
    }];
    
}
@end
