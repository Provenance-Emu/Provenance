//
//  ServiceProvider.h
//  TopShelf
//
//  Created by David Muzi on 2015-12-15.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <TVServices/TVServices.h>

/** Enabling Top Shelf
 
 1. Enable App Groups on the TopShelf target, and specify an App Group ID
        Provenance Project -> TopShelf Target -> Capabilities Section -> App Groups
 2. Enable App Groups on the Provenance TV target, using the same App Group ID
 3. Define the value for `PVAppGroupId` in `PVAppConstants.m` to that App Group ID
 
 */

@interface ServiceProvider : NSObject <TVTopShelfProvider>

@end

