//
//  PathsViewController.h
//  emulator
//
//  Created by Karen Tsai on 2014/3/5.
//  Copyright (c) 2014 Karen Tsai (angelXwind). All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PathsViewController : UITableViewController <UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UIBarButtonItem *sidebarButton;

@property (nonatomic, strong) NSMutableArray* diskImages;

@end
