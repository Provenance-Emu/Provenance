//
//  ORSAvailableDevicesTableViewController.m
//  MIDI Soundboard
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Open Reel Software. All rights reserved.
//

#import "ORSAvailableDevicesTableViewController.h"
#import <MIKMIDI/MIKMIDI.h>

@interface ORSAvailableDevicesTableViewController ()

@property (nonatomic, strong) MIKMIDIDeviceManager *deviceManager;

@end

@implementation ORSAvailableDevicesTableViewController

- (void)dealloc
{
    self.deviceManager = nil; // Break KVO
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	NSInteger result = [[[self deviceManager] availableDevices] count];
	NSLog(@"%s %li", __PRETTY_FUNCTION__, (long)result);
	return result;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *result = [tableView dequeueReusableCellWithIdentifier:@"AvailableDeviceTableViewCell" forIndexPath:indexPath];
	result.textLabel.text = [self.deviceManager.availableDevices[indexPath.row] name];
	return result;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	MIKMIDIDevice *selectedDevice = self.deviceManager.availableDevices[indexPath.row];
	if ([self.delegate respondsToSelector:@selector(availableDevicesTableViewController:midiDeviceWasSelected:)]) {
		[self.delegate availableDevicesTableViewController:self midiDeviceWasSelected:selectedDevice];
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"availableDevices"]) {
		[self.tableView reloadData];
	}
}

#pragma mark - Properties

@synthesize deviceManager = _deviceManager;

- (void)setDeviceManager:(MIKMIDIDeviceManager *)deviceManager
{
	if (deviceManager != _deviceManager) {
		[_deviceManager removeObserver:self forKeyPath:@"availableDevices"];
		_deviceManager = deviceManager;
		[_deviceManager addObserver:self forKeyPath:@"availableDevices" options:NSKeyValueObservingOptionInitial context:NULL];
	}
}

- (MIKMIDIDeviceManager *)deviceManager
{
	if (!_deviceManager) {
		self.deviceManager = [MIKMIDIDeviceManager sharedDeviceManager];
	}
	return _deviceManager;
}

@end
