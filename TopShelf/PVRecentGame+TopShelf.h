//
//  PVRecentGame+TopShelf.h
//  Provenance
//
//  Created by David Muzi on 2015-12-15.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import "PVRecentGame.h"
@import TVServices;

@interface PVRecentGame (TopShelf)

- (TVContentItem *)contentItemWithIdentifier:(TVContentIdentifier *)containerIdentifier;

@end
