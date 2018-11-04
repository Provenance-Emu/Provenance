//
//  Created by Cédric Luthi on 25/04/16.
//  Copyright © 2016 Cédric Luthi. All rights reserved.
//

#import "MainViewController.h"

#import <CocoaLumberjack/CocoaLumberjack.h>
#import <mach-o/ldsyms.h>
#import <mach-o/getsect.h>

@implementation MainViewController

- (void) viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	self.navigationItem.prompt = [[NSUserDefaults standardUserDefaults] stringForKey:@"NSLoggerBonjourServiceName"];
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	unsigned long length;
	uint8_t *bytes = getsectiondata(&_mh_execute_header, "__TEXT", "__text", &length);
	switch (indexPath.row)
	{
		case 0: DDLogError(@"Error log sample"); break;
		case 1: DDLogWarn(@"Warning log sample"); break;
		case 2: DDLogInfo(@"Info log sample"); break;
		case 3: DDLogDebug(@"Debug log sample"); break;
		case 4: DDLogVerbose(@"%@", [NSData dataWithBytesNoCopy:bytes length:length freeWhenDone:NO].description); break;
		default: break;
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
