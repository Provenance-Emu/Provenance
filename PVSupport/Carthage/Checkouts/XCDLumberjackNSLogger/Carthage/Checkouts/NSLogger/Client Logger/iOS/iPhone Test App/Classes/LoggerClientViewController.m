/*
 * LoggerClientViewController.m
 *
 * BSD license follows (http://www.opensource.org/licenses/bsd-license.php)
 * 
 * Copyright (c) 2010 Florent Pillet <fpillet@gmail.com> All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of  source code  must retain  the above  copyright notice,
 * this list of  conditions and the following  disclaimer. Redistributions in
 * binary  form must  reproduce  the  above copyright  notice,  this list  of
 * conditions and the following disclaimer  in the documentation and/or other
 * materials  provided with  the distribution.  Neither the  name of  Florent
 * Pillet nor the names of its contributors may be used to endorse or promote
 * products  derived  from  this  software  without  specific  prior  written
 * permission.  THIS  SOFTWARE  IS  PROVIDED BY  THE  COPYRIGHT  HOLDERS  AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A  PARTICULAR PURPOSE  ARE DISCLAIMED.  IN  NO EVENT  SHALL THE  COPYRIGHT
 * HOLDER OR  CONTRIBUTORS BE  LIABLE FOR  ANY DIRECT,  INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY,  OR CONSEQUENTIAL DAMAGES (INCLUDING,  BUT NOT LIMITED
 * TO, PROCUREMENT  OF SUBSTITUTE GOODS  OR SERVICES;  LOSS OF USE,  DATA, OR
 * PROFITS; OR  BUSINESS INTERRUPTION)  HOWEVER CAUSED AND  ON ANY  THEORY OF
 * LIABILITY,  WHETHER  IN CONTRACT,  STRICT  LIABILITY,  OR TORT  (INCLUDING
 * NEGLIGENCE  OR OTHERWISE)  ARISING  IN ANY  WAY  OUT OF  THE  USE OF  THIS
 * SOFTWARE,   EVEN  IF   ADVISED  OF   THE  POSSIBILITY   OF  SUCH   DAMAGE.
 * 
 */
#import "LoggerClientViewController.h"

#define TEST_FILE_BUFFERING 0

@implementation LoggerClientViewController

- (void)awakeFromNib
{
	tagsArray = [[NSArray arrayWithObjects:@"main",@"audio",@"video",@"network",@"database",nil] retain];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	viewerHostField.text = [ud stringForKey:@"host"];
	viewerPortField.text = [ud stringForKey:@"port"];
	browseBonjour.on = [ud boolForKey:@"browseBonjour"];
	browseLocalDomainOnly.on = [ud boolForKey:@"localDomain"];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(textFieldDidChange:)
												 name:UITextFieldTextDidChangeNotification
											   object:nil];

#if TEST_FILE_BUFFERING
	NSString *bufferPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"NSLoggerTempData_iOS.rawnsloggerdata"];
	LoggerSetBufferFile(NULL, (CFStringRef)bufferPath);
#endif
}

- (IBAction)bonjourSettingChanged
{
	browseLocalDomainOnly.enabled = browseBonjour.on;
	[[NSUserDefaults standardUserDefaults] setBool:browseBonjour.on forKey:@"browseBonjour"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction)browseLocalDomainOnlySettingChanged
{
	[[NSUserDefaults standardUserDefaults] setBool:browseLocalDomainOnly.on forKey:@"localDomain"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction)startStopSendingMessages
{
	if (sendTimer == nil)
	{
		// Configure the logger
		NSString *host = [viewerHostField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		int port = [viewerPortField.text integerValue];
		port = MAX(0, MIN(port, 65535));
		viewerPortField.text = [NSString stringWithFormat:@"%d", port];

		if ([host length] && port != 0)
			LoggerSetViewerHost(NULL, (CFStringRef)host, (UInt32)port);
		else
			LoggerSetViewerHost(NULL, NULL, 0);

		LoggerSetOptions(NULL,						// configure the default logger
						 kLoggerOption_BufferLogsUntilConnection |
						 kLoggerOption_UseSSL |
						 (browseBonjour.on ? kLoggerOption_BrowseBonjour : 0) |
						 (browseLocalDomainOnly.on ? kLoggerOption_BrowseOnlyLocalDomain : 0));

		// Start logging random messages
		counter = 0;
		imagesCounter = 0;
		sendTimer = [[NSTimer scheduledTimerWithTimeInterval:0.20f
													  target:self
													selector:@selector(sendTimerFired:)
													userInfo:nil
													 repeats:YES] retain];
		[timerButton setTitle:@"Stop Sending Logs" forState:UIControlStateNormal];
	}
	else
	{
		[sendTimer invalidate];
		[sendTimer release];
		sendTimer = nil;
		[timerButton setTitle:@"Start Sending Logs" forState:UIControlStateNormal];
	}
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if (textField == viewerHostField)
		[viewerPortField becomeFirstResponder];
	else
		[textField resignFirstResponder];
	return NO;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
	// we use the numbers & punct keyboard to get the Done key,
	// in exchange we need to validate input to exclude non-number chars
	if (textField != viewerPortField)
		return YES;
	NSMutableString *s = [string mutableCopy];
	NSUInteger length = [string length];
	for (NSUInteger i = 0; i < length; i++)
	{
		unichar c = [string characterAtIndex:i];
		if (c < '0' || c > '9')
		{
			[s replaceCharactersInRange:NSMakeRange(i, 1) withString:@""];
			length--;
		}
	}
	NSMutableString *ts = [textField.text mutableCopy];
	[ts replaceCharactersInRange:range withString:s];
	textField.text = ts;
	[ts release];
	[s release];
	return NO;
}

- (void)textFieldDidChange:(NSNotification *)note
{
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	[ud setObject:viewerHostField.text forKey:@"host"];
	[ud setObject:viewerPortField.text forKey:@"port"];
	[ud synchronize];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[sendTimer invalidate];
	[sendTimer release];
	[tagsArray release];
    [super dealloc];
}

- (void)sendTimerFired:(NSTimer *)timer
{
	static int image = 1;
	int phase = arc4random() % 10;
	if (phase != 1 && phase != 5)
	{
		NSMutableString *s = [NSMutableString stringWithFormat:@"test log message %d - Random characters follow: ", counter++];
		int nadd = 1 + arc4random() % 150;
		for (int i = 0; i < nadd; i++)
			[s appendFormat:@"%c", 32 + (arc4random() % 27)];
		LogMessage([tagsArray objectAtIndex:(arc4random() % [tagsArray count])], arc4random() % 3, s);
	}
	else if (phase == 1)
	{
		unsigned char *buf = (unsigned char *)malloc(1024);
		int n = 1 + arc4random() % 1024;
		for (int i = 0; i < n; i++)
			buf[i] = (unsigned char)arc4random();
		NSData *d = [[NSData alloc] initWithBytesNoCopy:buf length:n];
		LogData(@"main", 1, d);
		[d release];
	}
	else if (phase == 5)
	{
		imagesCounter++;
		UIGraphicsBeginImageContext(CGSizeMake(100, 100));
		CGContextRef ctx = UIGraphicsGetCurrentContext();
		CGFloat r = (CGFloat)(arc4random() % 256) / 255.0f;
		CGFloat g = (CGFloat)(arc4random() % 256) / 255.0f;
		CGFloat b = (CGFloat)(arc4random() % 256) / 255.0f;
		UIColor *fillColor = [UIColor colorWithRed:r green:g blue:b alpha:1.0f];
		CGContextSetFillColorWithColor(ctx, fillColor.CGColor);
		CGContextFillRect(ctx, CGRectMake(0, 0, 100, 100));
		CGContextSetTextMatrix(ctx, CGAffineTransformConcat(CGAffineTransformMakeTranslation(0, 100), CGAffineTransformMakeScale(1.0f, -1.0f)));
		CGContextSelectFont(ctx, "Helvetica", 14.0, kCGEncodingMacRoman);
		CGContextSetShadowWithColor(ctx, CGSizeMake(1, 1), 1.0f, [UIColor whiteColor].CGColor);
		CGContextSetTextDrawingMode(ctx, kCGTextFill);
		CGContextSetFillColorWithColor(ctx, [UIColor blackColor].CGColor);
		char buf[64];
		sprintf(buf, "Log Image %d", image++);
		CGContextShowTextAtPoint(ctx, 0, 50, buf, strlen(buf));
		UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
		CGSize sz = img.size;
		LogImageData(@"image", 0, sz.width, sz.height, UIImagePNGRepresentation(img));
		UIGraphicsEndImageContext();
	}
	if (phase == 0)
	{
		[NSThread detachNewThreadSelector:@selector(sendLogFromAnotherThread:)
								 toTarget:self
							   withObject:[NSNumber numberWithInteger:counter++]];
	}
	messagesSentLabel.text = [NSString stringWithFormat:@"%d", counter];
	imagesSentLabel.text = [NSString stringWithFormat:@"%d", imagesCounter];
}

- (void)sendLogFromAnotherThread:(NSNumber *)counterNum
{
	LogMessage(@"transfers", 0, @"message %d from standalone thread", [counterNum integerValue]);
}

@end
