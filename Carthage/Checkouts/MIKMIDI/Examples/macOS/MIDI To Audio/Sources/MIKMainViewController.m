//
//  ViewController.m
//  MIDI To Audio
//
//  Created by Andrew Madsen on 2/13/15.
//  Copyright (c) 2015-2016 Mixed In Key. All rights reserved.
//
//	Permission is hereby granted, free of charge, to any person obtaining a
//	copy of this software and associated documentation files (the
//	"Software"), to deal in the Software without restriction, including
//	without limitation the rights to use, copy, modify, merge, publish,
//	distribute, sublicense, and/or sell copies of the Software, and to
//	permit persons to whom the Software is furnished to do so, subject to
//	the following conditions:
//
//	The above copyright notice and this permission notice shall be included
//	in all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//	IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//	CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//	TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//	SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "MIKMainViewController.h"
#import "MIKMIDIToAudioExporter.h"

@interface MIKMainViewController ()

@property (nonatomic, getter=isExporting, readwrite) BOOL exporting;

@property (nonatomic, strong) MIKMIDIToAudioExporter *exporter;

@end

@implementation MIKMainViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	[self.view registerForDraggedTypes:@[NSFilenamesPboardType]];
}

- (IBAction)chooseFile:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	openPanel.allowedFileTypes = @[@"mid", @"midi"];
	openPanel.allowsMultipleSelection = NO;
	openPanel.canChooseDirectories = NO;
	[openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
		if (result != NSFileHandlingPanelOKButton) return;
		
		[self convertFileAtURL:[openPanel URL]];
	}];
}

- (void)convertFileAtURL:(NSURL *)fileURL
{
	if (self.isExporting) return;
	self.exporting = YES;
	
	self.exporter = [MIKMIDIToAudioExporter exporterWithMIDIFileAtURL:fileURL];
	[self.exporter exportToAudioFileWithCompletionHandler:^(NSURL *audioFileURL, NSError *error) {
		self.exporting = NO;
		
		if (!audioFileURL) {
			if (error) {
				[NSApp presentError:error];
			}
			return;
		}
		
		NSSavePanel *savePanel = [NSSavePanel savePanel];
		savePanel.allowedFileTypes = @[[audioFileURL pathExtension]];
		[savePanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
			if (result != NSFileHandlingPanelOKButton) return;
			
			NSFileManager *fm = [NSFileManager defaultManager];
			NSError *error = nil;
			if (![fm moveItemAtURL:audioFileURL toURL:[savePanel URL] error:&error]) {
				[NSApp presentError:error];
			}
		}];
	}];
}

#pragma mark - MIKMainViewDelegate

- (BOOL)shouldAllowDropForFile:(NSURL *)fileURL
{
	if (self.isExporting) return NO;
	return [fileURL.pathExtension isEqualToString:@"mid"] || [fileURL.pathExtension isEqualToString:@"midi"];
}

- (void)fileWasDropped:(NSURL *)fileURL
{
	// Wait until next run loop cycle to allow drag to complete
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self convertFileAtURL:fileURL];
	});
}

@end
