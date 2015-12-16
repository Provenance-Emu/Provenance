//
//  PVRecentGame+TopShelf.m
//  Provenance
//
//  Created by David Muzi on 2015-12-15.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import "PVRecentGame+TopShelf.h"

/* TODO
- [ ] migrate DB to group container
- [ ] test different emulators
- [ ] gracefull fallback if no app group is specified
*/

@implementation PVRecentGame (TopShelf)

- (TVContentItem *)contentItemWithIdentifier:(TVContentIdentifier *)containerIdentifier
{
    TVContentIdentifier *identifier = [[TVContentIdentifier alloc] initWithIdentifier:self.game.md5Hash container:containerIdentifier];
    TVContentItem *item = [[TVContentItem alloc] initWithContentIdentifier:identifier];
    
    item.title = self.game.title;
    item.imageURL = [NSURL URLWithString:self.game.originalArtworkURL];
    item.imageShape = TVContentItemImageShapeHDTV;
    item.displayURL = self.displayURL;
    item.lastAccessedDate = self.lastPlayedDate;
    
    return item;
}

- (NSURL *)displayURL
{
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.scheme = @"provenance";
    components.path = @"PlayController";
    components.queryItems = @[[[NSURLQueryItem alloc] initWithName:@"md5" value:self.game.md5Hash]];
    
    return components.URL;
}
@end
