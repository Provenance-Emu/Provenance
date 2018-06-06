//
//  Created by Cédric Luthi on 26/04/16.
//  Copyright © 2016 Cédric Luthi. All rights reserved.
//

#import "BonjourClientsTableViewController.h"

#import <netinet/in.h>
#import <arpa/inet.h>

static NSArray<NSString *> * NetServiceAddresses(NSNetService *service)
{
	NSMutableArray<NSString *> *addresses = [NSMutableArray new];
	for (NSData *addressData in service.addresses)
	{
		NSString *addressDescription;
		if (addressData.length == sizeof(struct sockaddr_in6))
		{
			char ip[INET6_ADDRSTRLEN] = {0};
			inet_ntop(AF_INET6, addressData.bytes + offsetof(struct sockaddr_in6, sin6_addr), ip, sizeof(ip));
			addressDescription = [NSString stringWithFormat:@"[%@]:%@", @(ip), @(service.port)];
		}
		else if (addressData.length == sizeof(struct sockaddr_in))
		{
			char ip[INET_ADDRSTRLEN] = {0};
			inet_ntop(AF_INET, addressData.bytes + offsetof(struct sockaddr_in, sin_addr), ip, sizeof(ip));
			addressDescription = [NSString stringWithFormat:@"%@:%@", @(ip), @(service.port)];
		}
		else
		{
			addressDescription = addressData.description;
		}
		[addresses addObject:addressDescription];
	}
	return addresses;
}

@interface BonjourClientsTableViewController () <NSNetServiceBrowserDelegate, NSNetServiceDelegate>
@property (nonatomic, strong) NSNetServiceBrowser *netServiceBrowser;
@property (nonatomic, strong) NSMutableArray<NSNetService *> *services;
@end

@implementation BonjourClientsTableViewController

- (NSMutableArray *) services
{
	if (!_services)
		_services = [NSMutableArray new];
	return _services;
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	self.netServiceBrowser = [NSNetServiceBrowser new];
	self.netServiceBrowser.includesPeerToPeer = YES;
	self.netServiceBrowser.delegate = self;
	[self.netServiceBrowser searchForServicesOfType:@"_nslogger-ssl._tcp." inDomain:@""];
}

- (IBAction) cancel:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction) disconnect:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"NSLoggerBonjourServiceName"];
	
	[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - NSNetServiceBrowserDelegate

static NSString * NSNetServicesErrorDescription(NSNetServicesError error)
{
	switch (error)
	{
		case NSNetServicesUnknownError:       return @"An unknown error occured during resolution or publication.";
		case NSNetServicesCollisionError:     return @"An NSNetService with the same domain, type and name was already present when the publication request was made.";
		case NSNetServicesNotFoundError:      return @"The NSNetService was not found when a resolution request was made.";
		case NSNetServicesActivityInProgress: return @"A publication or resolution request was sent to an NSNetService instance which was already published or a search request was made of an NSNetServiceBrowser instance which was already searching.";
		case NSNetServicesBadArgumentError:   return @"An required argument was not provided when initializing the NSNetService instance.";
		case NSNetServicesCancelledError:     return @"The operation being performed by the NSNetService or NSNetServiceBrowser instance was cancelled.";
		case NSNetServicesInvalidError:       return @"An invalid argument was provided when initializing the NSNetService instance or starting a search with an NSNetServiceBrowser instance.";
		case NSNetServicesTimeoutError:       return @"Resolution of an NSNetService instance failed because the timeout was reached.";
	}
	return [NSString stringWithFormat:@"NSNetServicesError %@", @(error)];
}

- (void) netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary<NSString *, NSNumber *> *)errorDict
{
	NSString *message = NSNetServicesErrorDescription(errorDict[NSNetServicesErrorCode].integerValue);
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Bonjour Error" message:message preferredStyle:UIAlertControllerStyleAlert];
	[alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
		[self dismissViewControllerAnimated:YES completion:nil];
	}]];
	[self presentViewController:alertController animated:YES completion:nil];
}

- (void) netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing
{
	[service setDelegate:self];
	[service resolveWithTimeout:10];
	
	[self.services addObject:service];
	[self.tableView insertRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:self.services.count - 1 inSection:0] ] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void) netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing
{
	NSUInteger serviceIndex = [self.services indexOfObject:service];
	if (serviceIndex != NSNotFound)
	{
		[self.services removeObjectAtIndex:serviceIndex];
		[self.tableView deleteRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:serviceIndex inSection:0] ] withRowAnimation:UITableViewRowAnimationAutomatic];
	}
}

#pragma mark - UITableView

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.services.count;
}

- (NSIndexPath *) tableView:(UITableView *)tableView willSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
	BOOL isSelectedServiceName = [self.services[indexPath.row].name isEqualToString:[[NSUserDefaults standardUserDefaults] stringForKey:@"NSLoggerBonjourServiceName"]];
	return isSelectedServiceName ? nil : indexPath;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BonjourClientCell" forIndexPath:indexPath];
	NSNetService *service = self.services[indexPath.row];
	BOOL isSelectedServiceName = [service.name isEqualToString:[[NSUserDefaults standardUserDefaults] stringForKey:@"NSLoggerBonjourServiceName"]];
	cell.textLabel.text = service.name;
	cell.detailTextLabel.text = [NetServiceAddresses(service) componentsJoinedByString:@" ◇ "];
	cell.accessoryType = isSelectedServiceName ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	cell.selectionStyle = isSelectedServiceName ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleGray;
	return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[[NSUserDefaults standardUserDefaults] setObject:self.services[indexPath.row].name forKey:@"NSLoggerBonjourServiceName"];
	
	[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - NSNetServiceDelegate

- (void) reloadService:(NSNetService *)service
{
	NSUInteger serviceIndex = [self.services indexOfObject:service];
	if (serviceIndex != NSNotFound)
	{
		[self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:serviceIndex inSection:0] ] withRowAnimation:UITableViewRowAnimationAutomatic];
	}
}

- (void) netServiceDidResolveAddress:(NSNetService *)service
{
	[self reloadService:service];
}

- (void) netService:(NSNetService *)service didNotResolve:(NSDictionary<NSString *, NSNumber *> *)errorDict;
{
	NSLog(@"netService:%@ didNotResolve:%@", service, errorDict);
	[self reloadService:service];
}

@end
