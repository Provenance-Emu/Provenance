//
//  PVConflictViewController.h
//  Provenance
//
//  Created by James Addyman on 17/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PVGameImporter;

@interface PVConflictViewController : UITableViewController

- (instancetype __nonnull)initWithGameImporter:(PVGameImporter * __nonnull)gameImporter;

@end
