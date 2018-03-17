//
//  PViCadeReader.h
//  Provenance
//
//  Created by Josejulio Martínez on 19/06/15.
//  Copyright (c) 2015 Josejulio Martínez. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "iCadeState.h"
#import "iCadeReaderView.h"

@interface PViCadeReader : NSObject<iCadeEventDelegate> {
    iCadeReaderView* _internalReader;
}

+(instancetype __nonnull) sharedReader;

-(void) listenToWindow:(UIWindow * __nullable)window;
-(void) listenToKeyWindow;
-(void) stopListening;
-(iCadeState) state;

@property (copy, nullable) void (^buttonDown)(iCadeState state);
@property (copy, nullable) void (^buttonUp)(iCadeState state);

@end
