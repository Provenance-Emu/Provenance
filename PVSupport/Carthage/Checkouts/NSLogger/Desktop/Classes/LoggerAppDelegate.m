/*
 * LoggerAppDelegate.h
 *
 * BSD license follows (http://www.opensource.org/licenses/bsd-license.php)
 * 
 * Copyright (c) 2010-2017 Florent Pillet <fpillet@gmail.com> All Rights Reserved.
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
#import <Security/SecItem.h>
#import <HockeySDK/HockeySDK.h>
#import "LoggerAppDelegate.h"
#import "LoggerNativeTransport.h"
#import "LoggerWindowController.h"
#import "LoggerDocument.h"
#import "LoggerDocumentController.h"
#import "LoggerStatusWindowController.h"
#import "LoggerPrefsWindowController.h"
#import "LoggerMessageCell.h"

NSString * const kPrefKeepMultipleRuns = @"keepMultipleRuns";
NSString * const kPrefCloseWithoutSaving = @"closeWithoutSaving";

NSString * const kPrefPublishesBonjourService = @"publishesBonjourService";
NSString * const kPrefHasDirectTCPIPResponder = @"hasDirectTCPIPResponder";
NSString * const kPrefDirectTCPIPResponderPort = @"directTCPIPResponderPort";
NSString * const kPrefBonjourServiceName = @"bonjourServiceName";
NSString * const kPrefClientApplicationSettings = @"clientApplicationSettings";

NSString * const kPref_ApplicationFilterSet = @"appFilterSet";

@implementation LoggerAppDelegate
@synthesize transports, filterSets, filtersSortDescriptors, statusController;
@synthesize serverCerts, serverCertsLoadAttempted;

+ (NSDictionary *)defaultPreferences
{
	static NSDictionary *sDefaultPrefs = nil;
	if (sDefaultPrefs == nil)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		sDefaultPrefs = [[NSDictionary alloc] initWithObjectsAndKeys:
						 //						 [NSNumber numberWithBool:NO], k
						 [NSNumber numberWithBool:YES], kPrefPublishesBonjourService,
						 [NSNumber numberWithBool:NO], kPrefHasDirectTCPIPResponder,
						 [NSNumber numberWithInteger:50000], kPrefDirectTCPIPResponderPort,
                         @"", kPrefBonjourServiceName,
                         [NSNumber numberWithBool:YES], kPrefKeepMultipleRuns,
						 nil];
		[pool release];
	}
	return sDefaultPrefs;
}

+ (void)load
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:[self defaultPreferences]];
}

- (id) init
{
	if ((self = [super init]) != nil)
	{
		transports = [[NSMutableArray alloc] init];

		// default filter ordering. The first sort descriptor ensures that the object with
		// uid 1 (the "Default Set" filter set or "All Logs" filter) is always on top. Other
		// items are ordered by title.
		self.filtersSortDescriptors = [NSArray arrayWithObjects:
									   [NSSortDescriptor sortDescriptorWithKey:@"uid" ascending:YES
																	comparator:
										^(id uid1, id uid2)
		{
			if ([uid1 integerValue] == 1)
				return (NSComparisonResult)NSOrderedAscending;
			if ([uid2 integerValue] == 1)
				return (NSComparisonResult)NSOrderedDescending;
			return (NSComparisonResult)NSOrderedSame;
		}],
									   [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES],
									   nil];
		
		// resurrect filters before the app nib loads
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSData *filterSetsData = [defaults objectForKey:@"filterSets"];
		if (filterSetsData != nil)
		{
			filterSets = [[NSKeyedUnarchiver unarchiveObjectWithData:filterSetsData] retain];
			if (![filterSets isKindOfClass:[NSMutableArray class]])
			{
				[filterSets release];
				filterSets = nil;
			}
		}
		if (filterSets == nil)
			filterSets = [[NSMutableArray alloc] init];
		if (![filterSets count])
		{
			NSMutableArray *filters = nil;

			// Try to reload pre-1.0b4 filters (will remove this code soon)
			NSData *filterData = [defaults objectForKey:@"filters"];
			if (filterData != nil)
			{
				filters = [NSKeyedUnarchiver unarchiveObjectWithData:filterData];
				if (![filters isMemberOfClass:[NSMutableArray class]])
					filters = nil;
			}
			if (filters == nil)
			{
				// Create a default set
				filters = [self defaultFilters];
			}
			NSMutableDictionary *defaultSet = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
											   NSLocalizedString(@"Default Set", @""), @"title",
											   [NSNumber numberWithInteger:1], @"uid",
											   filters, @"filters",
											   nil];
			[filterSets addObject:defaultSet];
			[defaultSet release];
		}
		
		// fix for issue found by Stefan Neumärker: default filters in versions 1.0b7 were immutable,
		// leading to a crash if the user tried to edit them
		for (NSDictionary *dict in filterSets)
		{
			NSMutableArray *filters = [dict objectForKey:@"filters"];
			for (NSUInteger i = 0; i < [filters count]; i++)
			{
				if (![[filters objectAtIndex:i] isMemberOfClass:[NSMutableDictionary class]])
				{
					[filters replaceObjectAtIndex:i
									   withObject:[[[filters objectAtIndex:i] mutableCopy] autorelease]];
				}
			}
		}

        [LoggerMessageCell loadAdvancedColorsPrefs];
	}
	return self;
}

- (void)dealloc
{
	if (serverCerts != NULL)
		CFRelease(serverCerts);
	[transports release];
	[super dealloc];
}

- (void)saveFiltersDefinition
{
	@try
	{
		NSData *filterSetsData = [NSKeyedArchiver archivedDataWithRootObject:filterSets];
		if (filterSetsData != nil)
		{
			[[NSUserDefaults standardUserDefaults] setObject:filterSetsData forKey:@"filterSets"];
			// remove pre-1.0b4 filters
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"filters"];
		}
	}
	@catch (NSException * e)
	{
		NSLog(@"Caught exception while trying to archive filters: %@", e);
	}
}

- (void)prefsChangeNotification:(NSNotification *)note
{
	[self performSelector:@selector(startStopTransports) withObject:nil afterDelay:0];
    [LoggerMessageCell loadAdvancedColors];
}

- (void)startStopTransports
{
	// Start and stop transports as needed
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	for (LoggerTransport *transport in transports)
	{
		if ([transport isKindOfClass:[LoggerNativeTransport class]])
		{
			LoggerNativeTransport *t = (LoggerNativeTransport *)transport;
			if (t.publishBonjourService)
			{
				if ([[ud objectForKey:kPrefPublishesBonjourService] boolValue])
					[t restart];
				else if (t.active)
					[t shutdown];
			}
			else
			{
				if ([[ud objectForKey:kPrefHasDirectTCPIPResponder] boolValue])
					[t restart];
				else
					[t shutdown];
			}
		}
	}
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	// instantiate our controller once to make it the shared document controller
	[LoggerDocumentController sharedDocumentController];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Initialize HockeyApp if properly configured
	NSDictionary *hockeyConf = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"HockeyConf" ofType:@"plist"]];
	NSString *hockeyAppID = [hockeyConf objectForKey:@"appID"];
	if ([hockeyAppID isKindOfClass:[NSString class]] && [hockeyAppID length])
	{
		BITHockeyManager *shm = [BITHockeyManager sharedHockeyManager];
		[shm configureWithIdentifier:hockeyAppID];
		[shm startManager];
	}
	
	// Listen to prefs change notifications, where we start / stop transports on demand
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(prefsChangeNotification:)
												 name:kPrefsChangedNotification
											   object:nil];
	// Prepare the logger status
	statusController = [[LoggerStatusWindowController alloc] initWithWindowNibName:@"LoggerStatus"];
	[statusController showWindow:self];

    // This window is rarely useful. But the best would probably be to open it in case of error.
    [statusController close];

	/* initialize all supported transports */
	
	// unencrypted Bonjour service (for backwards compatibility)
	LoggerNativeTransport *t = [[LoggerNativeTransport alloc] init];
	t.publishBonjourService = YES;
	t.secure = NO;
	[transports addObject:t];
	[t release];

	// SSL Bonjour service
	t = [[LoggerNativeTransport alloc] init];
	t.publishBonjourService = YES;
	t.secure = YES;
	[transports addObject:t];
	[t release];

	// Direct TCP/IP service (SSL mandatory)
	t = [[LoggerNativeTransport alloc] init];
	t.listenerPort = [[NSUserDefaults standardUserDefaults] integerForKey:kPrefDirectTCPIPResponderPort];
	t.secure = YES;
	[transports addObject:t];
	[t release];

	// start transports
	[self performSelector:@selector(startStopTransports) withObject:nil afterDelay:0];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	return NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	return NO;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return NO;
}

- (void)newConnection:(LoggerConnection *)aConnection fromTransport:(LoggerTransport *)aTransport
{
	// we are being called on the main thread (using dispatch_sync() from transport, so take care)
	assert([NSThread isMainThread]);

	// Go through all open documents,
	// Detect reconnection from a previously disconnected client
	NSDocumentController *docController = [NSDocumentController sharedDocumentController];
	for (LoggerDocument *doc in [docController documents])
	{
		if (![doc isKindOfClass:[LoggerDocument class]])
			continue;
		for (LoggerConnection *c in doc.attachedLogs)
		{
			if (c != aConnection && [aConnection isNewRunOfClient:c])
			{
				// recycle this document window, bring it to front
				aConnection.reconnectionCount = ((LoggerConnection *)[doc.attachedLogs lastObject]).reconnectionCount + 1;
				[doc addConnection:aConnection];
				return;
			}
		}
	}

	// Instantiate a new window for this connection
	LoggerDocument *doc = [[LoggerDocument alloc] initWithConnection:aConnection];
	[docController addDocument:doc];
	[doc makeWindowControllers];
	[doc showWindows];
	[doc release];
}

- (NSMutableArray *)defaultFilters
{
	NSMutableArray *filters = [NSMutableArray array];

	[filters addObject:[NSDictionary dictionaryWithObjectsAndKeys:
						[NSNumber numberWithInteger:1], @"uid",
						NSLocalizedString(@" All logs", @""), @"title",
						[NSPredicate predicateWithValue:YES], @"predicate",
						nil]];

	[filters addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
						[NSNumber numberWithInteger:2], @"uid",
						NSLocalizedString(@"Type: text", @""), @"title",
						[NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObject:[NSPredicate predicateWithFormat:@"(messageType == \"text\")"]]], @"predicate",
						nil]];

	[filters addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
						[NSNumber numberWithInteger:3], @"uid",
						NSLocalizedString(@"Type: image", @""), @"title",
						[NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObject:[NSPredicate predicateWithFormat:@"(messageType == \"img\")"]]], @"predicate",
						nil]];

	[filters addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
						[NSNumber numberWithInteger:4], @"uid",
						NSLocalizedString(@"Type: data", @""), @"title",
						[NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObject:[NSPredicate predicateWithFormat:@"(messageType == \"data\")"]]], @"predicate",
						nil]];

    [filters addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithInteger:5], @"uid",
                        NSLocalizedString(@" Errors", @""), @"title",
                        [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObject:[NSPredicate predicateWithFormat:@"(level == 0)"]]], @"predicate",
                        nil]];

    [filters addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithInteger:6], @"uid",
                        NSLocalizedString(@" Errors and warnings", @""), @"title",
                        [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObject:[NSPredicate predicateWithFormat:@"(level <= 1)"]]], @"predicate",
                        nil]];

    [filters addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                        [NSNumber numberWithInteger:7], @"uid",
                        NSLocalizedString(@" All but noise", @""), @"title",
                        [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObject:[NSPredicate predicateWithFormat:@"(level < 6)"]]], @"predicate",
                        nil]];

    for (NSString *domain in @[@"App", @"View", @"Controller", @"Service", @"Network", @"Model"]) {
        [filters addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithInteger:8], @"uid",
                            [NSString stringWithFormat:NSLocalizedString(@"Domain: %@", @""), domain], @"title",
                            [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObject:[NSPredicate predicateWithFormat:[NSString stringWithFormat:@"(tag == \"%@\")", domain]]]], @"predicate",
                            nil]];
    }

	return filters;
}

- (NSNumber *)nextUniqueFilterIdentifier:(NSArray *)filters
{
	// since we're using basic NSDictionary to store filters, we add a filter
	// identifier number so that no two filters are strictly identical -- makes
	// things much easier wih NSArrayController
	return [NSNumber numberWithInteger:[[filters valueForKeyPath:@"@max.uid"] integerValue] + 1];
}

- (IBAction)showPreferences:(id)sender
{
	if (prefsController == nil)
		prefsController = [[LoggerPrefsWindowController alloc] initWithWindowNibName:@"LoggerPrefs"];
	[prefsController showWindow:sender];
}

- (IBAction)showStatus:(id)sender
{
    [statusController.window makeKeyAndOrderFront:nil];
}

- (void)relaunchApplication
{
	NSString *appToRelaunch = [[NSBundle mainBundle] bundlePath];
	NSString *relaunchToolPath = [[[NSBundle mainBundle] sharedSupportPath] stringByAppendingPathComponent:@"relaunch"];
	[NSTask launchedTaskWithLaunchPath:relaunchToolPath
							 arguments:[NSArray arrayWithObjects:
										appToRelaunch,
										[NSString stringWithFormat:@"%d", [[NSProcessInfo processInfo] processIdentifier]],
										nil]];
	exit(0);	
}

- (BOOL)attemptRecoveryFromError:(NSError *)error optionIndex:(NSUInteger)recoveryOptionIndex
{
	[self relaunchApplication];
	return NO;
}

// -----------------------------------------------------------------------------
#pragma mark -
#pragma mark SSL support
// -----------------------------------------------------------------------------
- (BOOL)loadEncryptionCertificate:(NSError **)outError
{
	// Load the certificate we need to support encrypted incoming connections via SSL
	//
	// To this end, we will (once):
	// - generate a self-signed certificate and private key
	// - import the self-signed certificate and private key into the default keychain
	// - retrieve the certificate from the keychain
	// - create the required SecIdentityRef for the certificate to be recognized by the CFStream
	// - keep this in the running app and use for incoming connections

	if (outError != NULL)
		*outError = nil;

	serverCertsLoadAttempted = YES;

	SecKeychainRef keychain;
	NSString *failurePoint = NSLocalizedString(@"Can't get the default keychain", @"");
	OSStatus status = SecKeychainCopyDefault(&keychain);
	for (int pass = 0; pass < 2 && status == noErr && serverCerts == NULL; pass++)
	{
		// Search through existing identities to find our NSLogger certificate
		SecIdentitySearchRef searchRef = NULL;
		failurePoint = NSLocalizedString(@"Can't search through default keychain", @"");
		status = SecIdentitySearchCreate(keychain, CSSM_KEYUSE_ANY, &searchRef);
		if (status == noErr)
		{
			SecIdentityRef identityRef = NULL;
			while (serverCerts == NULL && SecIdentitySearchCopyNext(searchRef, &identityRef) == noErr)
			{
				SecCertificateRef certRef = NULL;
				if (SecIdentityCopyCertificate(identityRef, &certRef) == noErr)
				{
					CFStringRef commonName = NULL;
					if (SecCertificateCopyCommonName(certRef, &commonName) == noErr)
					{
						if (commonName != NULL && CFStringCompare(commonName, CFSTR("NSLogger self-signed SSL"), 0) == kCFCompareEqualTo)
						{
							// We found our identity
							CFTypeRef values[] = {
								identityRef, certRef
							};
							serverCerts = CFArrayCreate(NULL, values, 2, &kCFTypeArrayCallBacks);
						}
                        if (commonName != NULL)
                        {
                            CFRelease(commonName);
                        }
					}
					CFRelease(certRef);
				}
				CFRelease(identityRef);
			}
			CFRelease(searchRef);
			status = noErr;
		}
		
		// Not found: create a cert, import it
		if (serverCerts == NULL && status == noErr && pass == 0)
		{
			// Path to our self-signed certificate
			NSString *tempDir = NSTemporaryDirectory();
			NSString *pemFileName = @"NSLoggerCert.pem";
			NSString *pemFilePath = [tempDir stringByAppendingPathComponent:pemFileName];
			NSFileManager *fm = [NSFileManager defaultManager];
			[fm removeItemAtPath:pemFilePath error:nil];
			
			// Generate a private certificate
			NSArray *args = [NSArray arrayWithObjects:
							 @"req",
							 @"-x509",
							 @"-nodes",
							 @"-days", @"3650",
							 @"-config", [[NSBundle mainBundle] pathForResource:@"NSLoggerCertReq" ofType:@"conf"],
							 @"-newkey", @"rsa:1024",
							 @"-keyout", pemFileName,
							 @"-out", pemFileName,
							 @"-batch",
							 nil];
			
			NSTask *certTask = [[[NSTask alloc] init] autorelease];
			[certTask setLaunchPath:@"/usr/bin/openssl"];
			[certTask setCurrentDirectoryPath:tempDir];
			[certTask setArguments:args];
			[certTask launch];
			do
			{
				[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
			}
			while([certTask isRunning]);

			// Load the NSLogger self-signed certificate
			NSData *certData = [NSData dataWithContentsOfFile:pemFilePath];
			if (certData == nil)
			{
				failurePoint = NSLocalizedString(@"Can't load self-signed certificate data", @"");
				status = -1;
			}
			else
			{
				// Import certificate and private key into our private keychain
				SecKeyImportExportParameters kp;
				bzero(&kp, sizeof(kp));
				kp.version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION;
				SecExternalFormat inputFormat = kSecFormatPEMSequence;
				SecExternalItemType itemType = kSecItemTypeAggregate;
				failurePoint = NSLocalizedString(@"Failed importing self-signed certificate", @"");
				status = SecKeychainItemImport((CFDataRef)certData,
											   (CFStringRef)pemFileName,
											   &inputFormat,
											   &itemType,
											   0,				// flags are unused
											   &kp,				// import-export parameters
											   keychain,
											   NULL);
			}
		}
	}

	if (keychain != NULL)
		CFRelease(keychain);

	if (serverCerts == NULL && outError != NULL)
	{
		if (status == noErr)
			failurePoint = NSLocalizedString(@"Failed retrieving our self-signed certificate", @"");
		
		NSString *errMsg = [NSString stringWithFormat:NSLocalizedString(@"Our private encryption certificate could not be loaded (%@, error code %d)", @""),
							failurePoint, status];
		
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain
										code:status
									userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
											  NSLocalizedString(@"NSLogger won't be able to accept SSL connections", @""), NSLocalizedDescriptionKey,
											  errMsg, NSLocalizedFailureReasonErrorKey,
											  NSLocalizedString(@"Please contact the application developers", @""), NSLocalizedRecoverySuggestionErrorKey,
											  nil]];
	}

	return (serverCerts != NULL);
}

@end
