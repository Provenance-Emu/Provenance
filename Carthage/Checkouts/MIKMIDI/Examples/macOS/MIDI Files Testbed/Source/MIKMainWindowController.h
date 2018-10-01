//
//  MIKMainWindowController.h
//  MIDI Files Testbed
//
//  Created by Andrew Madsen on 2/20/15.
//  Copyright (c) 2015 Mixed In Key. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MIKMIDISequenceView.h"

@class MIKMIDIDeviceManager;
@class MIKMIDIDevice;

@interface MIKMainWindowController : NSWindowController <MIKMIDISequenceViewDelegate>

+ (instancetype)windowController;

- (IBAction)loadFile:(id)sender;
- (IBAction)toggleRecording:(id)sender;
- (IBAction)togglePlayback:(id)sender;

@property (nonatomic, readonly) MIKMIDIDeviceManager *deviceManager;

@property (nonatomic, strong) MIKMIDISequence *sequence;
@property (nonatomic, strong) MIKMIDIDevice *device;
@property (nonatomic, getter=isPlaying, readonly) BOOL playing;
@property (nonatomic, getter=isRecording, readonly) BOOL recording;

@property (weak) IBOutlet MIKMIDISequenceView *trackView;
@property (nonatomic, readonly) NSString *recordButtonLabel;
@property (nonatomic, readonly) NSString *playButtonLabel;

@end
