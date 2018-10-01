//
//  ORSSplitViewManager.h
//  MIDI Soundboard
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Open Reel Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ORSSplitViewManager : NSObject <UISplitViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UISplitViewController *splitViewController;

@end
