//
//  PViCadeReader.h
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "iCadeState.h"
#import "iCadeReaderView.h"

@interface PViCadeReader : NSObject<iCadeEventDelegate> {
    iCadeReaderView* _internalReader;
}

+(PViCadeReader*) sharedReader;

-(void) listenToKeyWindow;
-(iCadeState) state;

@property (copy) void (^stateChanged)(iCadeState state);
@property (copy) void (^buttonDown)(iCadeState state);
@property (copy) void (^buttonUp)(iCadeState state);

@end
