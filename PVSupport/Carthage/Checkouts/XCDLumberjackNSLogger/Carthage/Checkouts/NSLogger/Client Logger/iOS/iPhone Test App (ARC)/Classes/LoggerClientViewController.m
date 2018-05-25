/*
 * LoggerClientViewController.m
 *
 * BSD license follows (http://www.opensource.org/licenses/bsd-license.php)
 * 
 * Copyright (c) 2010-2011 Florent Pillet <fpillet@gmail.com> All Rights Reserved.
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
#define NUM_LOGGING_QUEUES	10

dispatch_queue_t loggingQueues[NUM_LOGGING_QUEUES];

void logRandomImage(int numImage)
{
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
	sprintf(buf, "Log Image %d", numImage);
	CGContextShowTextAtPoint(ctx, 0, 50, buf, strlen(buf));
	UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
	CGSize sz = img.size;
	LogImageData(@"image", 0, sz.width, sz.height, UIImagePNGRepresentation(img));
	UIGraphicsEndImageContext();
}

@implementation LoggerClientViewController

+ (void)load
{
	char label[32];
	for (int i=0; i < NUM_LOGGING_QUEUES; i++)
	{
		sprintf(label, "logging queue %d", i);
		loggingQueues[i] = dispatch_queue_create(label, NULL);
	}
}

- (void)awakeFromNib
{
	tagsArray = [NSArray arrayWithObjects:@"main",@"audio",@"video",@"network",@"database",nil];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	viewerHostField.text = [ud stringForKey:@"host"];
	viewerPortField.text = [ud stringForKey:@"port"];
	intervalField.text = [ud stringForKey:@"interval"];
	browseBonjour.on = [ud boolForKey:@"browseBonjour"];
	browseLocalDomainOnly.on = [ud boolForKey:@"localDomain"];
	sendImages.on = [ud boolForKey:@"sendImages"];

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

- (IBAction)sendImagesSettingChanged
{
	[[NSUserDefaults standardUserDefaults] setBool:sendImages.on forKey:@"sendImages"];
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
			LoggerSetViewerHost(NULL, (__bridge CFStringRef)host, (UInt32)port);
		else
			LoggerSetViewerHost(NULL, NULL, 0);

		BOOL useBonjour = browseBonjour.on;
		BOOL onlyLocalDomain = browseLocalDomainOnly.on;

		LoggerSetOptions(NULL,						// configure the default logger
						 kLoggerOption_BufferLogsUntilConnection |
						 kLoggerOption_UseSSL |
						 kLoggerOption_CaptureSystemConsole	|
						 (useBonjour ? kLoggerOption_BrowseBonjour : 0) |
						 (onlyLocalDomain ? kLoggerOption_BrowseOnlyLocalDomain : 0));

		// Start logging random messages
		counter = 0;
		imagesCounter = 0;
		sendTimer = [NSTimer scheduledTimerWithTimeInterval:0.001f * [intervalField.text integerValue]
													  target:self
													selector:@selector(sendTimerFired:)
													userInfo:nil
													 repeats:YES];
		[timerButton setTitle:@"Stop Sending Logs" forState:UIControlStateNormal];
	}
	else
	{
		[sendTimer invalidate];
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
	if (textField != viewerPortField && textField != intervalField)
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
	return NO;
}

- (void)textFieldDidChange:(NSNotification *)note
{
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	[ud setObject:viewerHostField.text forKey:@"host"];
	[ud setObject:viewerPortField.text forKey:@"port"];
	[ud setObject:intervalField.text forKey:@"interval"];
	[ud synchronize];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[sendTimer invalidate];
}

- (void)sendTimerFired:(NSTimer *)timer
{
	for (int q = 0; q < NUM_LOGGING_QUEUES; q++)
	{
		dispatch_async(loggingQueues[q], ^{
			int phase = arc4random() % 10;
			if (phase == 7)
			{
				NSLog(@"Some message %d to NSLog", counter++);
			}
			else if (phase == 6)
			{
				fprintf(stdout, "Some message %d to stdout\n", counter++);
				fflush(stdout);		// required for stdout to be flushed when not connected to Xcode debugger
			}
			else if (phase == 5)
			{
				fprintf(stderr, "Some message %d to stderr\n", counter++);
				fflush(stderr);
			}
			else if (phase != 1)
			{
				NSMutableString *s = [NSMutableString stringWithFormat:@"test log message %d - Random characters follow: ", counter++];
				int nadd = 1 + arc4random() % 150;
				for (int i = 0; i < nadd; i++)
					[s appendFormat:@"%c", 32 + (arc4random() % 27)];
				LogMessage([tagsArray objectAtIndex:(arc4random() % [tagsArray count])], arc4random() % 3, @"%@", s);
			}
			else if (phase == 1)
			{
				unsigned char *buf = (unsigned char *)malloc(1024);
				int n = 1 + arc4random() % 1024;
				for (int i = 0; i < n; i++)
					buf[i] = (unsigned char)arc4random();
				LogData(@"main", 1, [[NSData alloc] initWithBytesNoCopy:buf length:n]);
			}
			else if (phase == 5)
			{
				logRandomImage(++imagesCounter);
			}
			dispatch_async(dispatch_get_main_queue(), ^{
				messagesSentLabel.text = [NSString stringWithFormat:@"%d", counter];
				imagesSentLabel.text = [NSString stringWithFormat:@"%d", imagesCounter];
			});
		});
	}
}

@end
