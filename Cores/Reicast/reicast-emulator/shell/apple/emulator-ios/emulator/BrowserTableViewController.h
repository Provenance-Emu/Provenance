//
//  BrowserTableViewController.h
//  emulator
//
//  Created by Karen Tsai on 2014/3/5.
//  Copyright (c) 2014 Karen Tsai (angelXwind). All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BrowserTableViewController : UITableViewController {
    NSArray *games;
}
@property (weak, nonatomic) IBOutlet UIBarButtonItem *sidebarButton;

@end
