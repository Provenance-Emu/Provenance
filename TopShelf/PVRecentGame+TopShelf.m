//
//  PVRecentGame+TopShelf.m
//  Provenance
//
//  Created by David Muzi on 2015-12-15.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import "PVRecentGame+TopShelf.h"
#import "PVEmulatorConstants.h"
#import "PVAppConstants.h"

@implementation PVRecentGame (TopShelf)

- (TVContentItem *)contentItemWithIdentifier:(TVContentIdentifier *)containerIdentifier
{
    TVContentIdentifier *identifier = [[TVContentIdentifier alloc] initWithIdentifier:self.game.md5Hash container:containerIdentifier];
    TVContentItem *item = [[TVContentItem alloc] initWithContentIdentifier:identifier];
    
    item.title = self.game.title;
    item.imageURL = [NSURL URLWithString:self.game.originalArtworkURL];
    item.imageShape = self.imageType;
    item.displayURL = self.displayURL;
    item.lastAccessedDate = self.lastPlayedDate;
    
    return item;
}

- (NSURL *)displayURL
{
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.scheme = PVAppURLKey;
    components.path = PVGameControllerKey;
    components.queryItems = @[[[NSURLQueryItem alloc] initWithName:PVGameMD5Key value:self.game.md5Hash]];
    
    return components.URL;
}

- (TVContentItemImageShape)imageType
{
    if ([self.game.systemIdentifier isEqualToString:PVNESSystemIdentifier] ||
        [self.game.systemIdentifier isEqualToString:PVGenesisSystemIdentifier] ||
        [self.game.systemIdentifier isEqualToString:PVMasterSystemSystemIdentifier]) {
        return TVContentItemImageShapePoster;
    }
    else if ([self.game.systemIdentifier isEqualToString:PVGameGearSystemIdentifier]) {
        return TVContentItemImageShapeSquare;
    }

    return TVContentItemImageShapeHDTV;
}

@end
