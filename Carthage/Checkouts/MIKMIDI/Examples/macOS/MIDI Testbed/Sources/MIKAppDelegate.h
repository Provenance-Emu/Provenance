//
//  MIKAppDelegate.h
//  MIDI Testbed
//
//  Created by Andrew Madsen on 3/7/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MIKMIDIDeviceManager;
@class MIKMIDIDevice;
@class MIKMIDISourceEndpoint;

@interface MIKAppDelegate : NSObject <NSApplicationDelegate>

- (IBAction)sendSysex:(id)sender;

@property (assign) IBOutlet NSWindow *window;
@property (unsafe_unretained) IBOutlet NSTextView *textView;
@property (nonatomic, strong, readonly) NSArray *availableDevices;
@property (nonatomic, strong) MIKMIDIDevice *device;
@property (nonatomic, strong) MIKMIDISourceEndpoint *source;
@property (nonatomic, readonly) NSArray *availableCommands;
@property (weak) IBOutlet NSComboBox *commandComboBox;

@end
