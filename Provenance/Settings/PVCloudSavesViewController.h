//
//  PVCloudSavesViewController.h
//  Provenance
//
//  Created by Joshua Delman on 2/24/16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PVGameLibraryViewController.h"

@interface PVCloudSavesViewController : UITableViewController

@property (weak, nonatomic) NSDictionary *gamesInSections;
@property (weak, nonatomic) PVGameLibraryViewController *gameLibraryVC;

@end
