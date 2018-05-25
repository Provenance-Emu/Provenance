/*
 *
 * Modified BSD license.
 *
 * Copyright (c) 2012-2013 Sung-Taek, Kim <stkim1@colorfulglue.com> All Rights
 * Reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of  source code  must retain  the above  copyright notice,
 * this list of  conditions and the following  disclaimer. Redistributions in
 * binary  form must  reproduce  the  above copyright  notice,  this list  of
 * conditions and the following disclaimer  in the documentation and/or other
 * materials  provided with  the distribution.  Neither the  name of Sung-Tae
 * k Kim nor the names of its contributors may be used to endorse or promote
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



#import "LoggerDataManager.h"
#import "NSManagedObjectContext+FetchAdditions.h"
#import "NSFileManager+DirectoryLocations.h"
#import "SynthesizeSingleton.h"

#import "LoggerMessageData.h"
#import "LoggerNativeMessage.h"
#import "LoggerClientData.h"
#import "LoggerConnectionStatusData.h"
#include "time_converter.h"
#import <mach/mach_time.h>
#import "LoggerTransportManager.h"

/*
 Save operation is expensive. if we could reduce the frequency of save operation
 reasonably, we should follow the suit. A way to reduce the requency is batch 
 saving. Accumulate an approximated size of save operation and save in a shot. 
 
 It requires us to setup a threadhold size that could be used againt measure
 when to fire save(). I deciced to set a threadhold based on Florent advice of
 Flash memory paging. FLASH memory saves data by page, whose size is usually 
 4096 byte. Scheme is pretty simple that we will fire save() when we have more
 data than multiple of DEFAULT_FLASH_PAGING_SIZE to save
 */

#define DEFAULT_FLASH_PAGING_SIZE	4096
#define DEFAULT_SAVING_BLOCK_SIZE	(DEFAULT_FLASH_PAGING_SIZE << 1) // 8192

@interface LoggerDataManager()
@property (nonatomic, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, readonly) NSManagedObjectContext *messageProcessContext;
@property (nonatomic, readonly) NSManagedObjectContext *messageSaveContext;
-(void)_runMessageSaveChain:(unsigned long)theSaveDataSize
		withMainThreadBlock:(void (^)(NSError *saveError))aMainThreadBlock;

-(void)_runMessageSaveChain:(unsigned long)theSaveDataSize
		flushDisplayContext:(BOOL)flushDisplayContext
		withMainThreadBlock:(void (^)(NSError *saveError))aMainThreadBlock;
@end

@implementation LoggerDataManager
{
	NSManagedObjectModel	*_managedObjectModel;
	NSPersistentStoreCoordinator *_persistentStoreCoordinator;

	// The root disk save context
	NSManagedObjectContext	*_messageSaveContext;
	unsigned long			_messageSaveSizeCount;
	
	// Secondary display/UI context. NSFetchRequestController takes
	// this to display message on UITableViewCell
	NSManagedObjectContext	*_messageDisplayContext;
	
	// finally, mesage process queue and context
	NSManagedObjectContext	*_messageProcessContext;
	dispatch_queue_t		_messageProcessQueue;
	
	// data storage
	LoggerDataStorage		*_dataStorage;
	
}
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize messageDisplayContext = _messageDisplayContext;
@synthesize messageProcessContext = _messageProcessContext;
@synthesize messageSaveContext = _messageSaveContext;
@synthesize dataStorage = _dataStorage;

SYNTHESIZE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(LoggerDataManager,sharedDataManager);

-(id)init
{
	self = [super init];
	if(self)
	{
		
		// initialize resposible MOCs to wake up.
		[self managedObjectModel];
		[self persistentStoreCoordinator];
		
		// root disk save context
		[self messageSaveContext];
		
		// Secondary display/UI context. NSFetchRequestController takes
		// this to display message on UITableViewCell
		[self messageDisplayContext];

		// finally, mesage process queue and context
		_messageProcessQueue = \
			dispatch_queue_create("com.colorfulglue.nslogger-ipad",NULL);
		
		dispatch_sync(_messageProcessQueue, ^{
			[self messageProcessContext];
		});
		
		// very first save operation to initialize PSC
		dispatch_sync(_messageProcessQueue, ^{

			__block NSError *error = nil;
			__block BOOL	isSavedOk = NO;

			isSavedOk = [[self messageProcessContext] save:&error];
			
			if(!isSavedOk || error != nil)
			{
				MTLog(@"we have a save error on process MOC %@",[error localizedFailureReason]);
			}
			else
			{

				[[self messageDisplayContext]
				 performBlockAndWait:^{
					 
					 isSavedOk = [[self messageDisplayContext] save:&error];
					 
					 if(!isSavedOk || error != nil)
					 {
						 MTLog(@"we have a save error on process MOC %@",[error localizedFailureReason]);
					 }
					 else
					 {
						 // initialize PSC on disk
						 [[self messageSaveContext]
						  performBlockAndWait:^{
							  isSavedOk = [[self messageSaveContext] save:&error];
							  
							  if(!isSavedOk || error != nil)
							  {
								 MTLog(@"we have a save error on process MOC %@",[error localizedFailureReason]);
							  }
							  
						  }];
					 }
				 }];
			}
		});
		
	}
	return  self;
}

//------------------------------------------------------------------------------
#pragma mark - AppDelegateCycleHandle
//------------------------------------------------------------------------------
// when app did start
-(void)appStarted
{
	
}

// app resigned from activity (power button, home button clicked)
-(void)appResignActive
{
	
}

// app becomes active again
-(void)appBecomeActive
{
	
}

// app will terminate
-(void)appWillTerminate
{
	
}

//------------------------------------------------------------------------------
#pragma mark - property synthesis
//------------------------------------------------------------------------------
-(NSManagedObjectModel *)managedObjectModel
{
	if(_managedObjectModel == nil)
	{
		_managedObjectModel = \
		[[NSManagedObjectModel alloc] initWithContentsOfURL:
		 [[NSBundle mainBundle] URLForResource:@"LoggerMessages"
								 withExtension:@"momd"]
		 ];
	}
	return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
	if (_persistentStoreCoordinator != nil)
	{
		return _persistentStoreCoordinator;
	}
	
	_persistentStoreCoordinator = \
		[[NSPersistentStoreCoordinator alloc]
		 initWithManagedObjectModel:[self managedObjectModel]];

	NSString *storePath = \
		[[[NSFileManager defaultManager] applicationDocumentsDirectory]
		 stringByAppendingPathComponent: @"LoggerData.sqlite"];

	NSDictionary *options = \
		@{NSMigratePersistentStoresAutomaticallyOption:[NSNumber numberWithBool:YES]
		,NSInferMappingModelAutomaticallyOption:[NSNumber numberWithBool:YES]
		,NSReadOnlyPersistentStoreOption:[NSNumber numberWithBool:NO]};
	
	NSError *error;

	[_persistentStoreCoordinator
		addPersistentStoreWithType:NSSQLiteStoreType
					 configuration:nil
							   URL:[NSURL fileURLWithPath:storePath]
						   options:options
							 error:&error];

	return _persistentStoreCoordinator;
}

//------------------------------------------------------------------------------
#pragma mark - MOC setup
//------------------------------------------------------------------------------

/*
 This MOC is for writing to PSC. It has its own GCD queue, and you can tell it
 to do anything you want regarding to writing operation
 */
-(NSManagedObjectContext *)messageSaveContext
{
	NSPersistentStoreCoordinator *coordinator = nil;

	if(_messageSaveContext != nil)
	{
		return _messageSaveContext;
	}

	coordinator = [self persistentStoreCoordinator];
	MTAssert(coordinator != nil, @"PSC must never be nil atm");
	
	if(coordinator != nil)
	{
		// this context must  be created from main thread
		assert([NSThread isMainThread]);

		_messageSaveContext = \
			[[NSManagedObjectContext alloc]
			 initWithConcurrencyType:NSPrivateQueueConcurrencyType];
		
		[_messageSaveContext
		 performBlockAndWait:^{
			 [_messageSaveContext setPersistentStoreCoordinator:coordinator];

			 // undo-manager is not necessary for entire app
			 [_messageSaveContext setUndoManager:nil];
		 }];
	}
	
	return _messageSaveContext;
}

/*
 this is displaying MOC. It will be connected to NSFetchResultController.
 */
- (NSManagedObjectContext *)messageDisplayContext
{
	
	if (_messageDisplayContext != nil)
	{
		return _messageDisplayContext;
	}

	NSManagedObjectContext *saveContext = [self messageSaveContext];
	MTAssert(saveContext != nil, @"A parent MOC must not be nil");

	if(saveContext != nil)
	{
		// this context must  be created from main thread
		assert([NSThread isMainThread]);
		
		_messageDisplayContext = \
			[[NSManagedObjectContext alloc]
			 initWithConcurrencyType:NSMainQueueConcurrencyType];
		[_messageDisplayContext setParentContext:saveContext];
		[_messageDisplayContext setUndoManager:nil];
	}

	return _messageDisplayContext;
}

// A mesage process queue and context
- (NSManagedObjectContext *)messageProcessContext
{
/*
 message processing context must be invoked within messageProcessQueue only.
 dispatch_get_current_queue is depricated from ios 6.0. so that's fine to use 
 for a while
 */
	assert(dispatch_get_current_queue() == _messageProcessQueue);
	
	if(_messageProcessContext != nil)
	{
		return _messageProcessContext;
	}
	
	NSManagedObjectContext *displayContext = [self messageDisplayContext];
	MTAssert(displayContext != nil, @"A display MOC should not be nil");

	if(displayContext != nil)
	{
		_messageProcessContext = \
			[[NSManagedObjectContext alloc]
			 initWithConcurrencyType:NSConfinementConcurrencyType];
		[_messageProcessContext setParentContext:displayContext];
		[_messageProcessContext setUndoManager:nil];
	}
	
	return _messageProcessContext;
}


//------------------------------------------------------------------------------
#pragma mark - save message chain
//------------------------------------------------------------------------------
-(void)_runMessageSaveChain:(unsigned long)theSaveDataSize
		withMainThreadBlock:(void (^)(NSError *saveError))aMainThreadBlock
{
	[self
	 _runMessageSaveChain:theSaveDataSize
	 flushDisplayContext:NO
	 withMainThreadBlock:aMainThreadBlock];	
}

-(void)_runMessageSaveChain:(unsigned long)theSaveDataSize
		flushDisplayContext:(BOOL)flushDisplayContext
		withMainThreadBlock:(void (^)(NSError *saveError))aMainThreadBlock
{
	assert(dispatch_get_current_queue() == _messageProcessQueue);
	
	BOOL	isProcessMocSavedOk = NO;
	NSError *processMocSaveError = nil;
	isProcessMocSavedOk =
		[[self messageProcessContext] save:&processMocSaveError];
	
	if(!isProcessMocSavedOk || processMocSaveError != nil)
	{
		MTLog(@"we have a save error on message_q [%@](%@)"
			  ,[processMocSaveError domain]
			  ,[processMocSaveError localizedDescription]);
	}
	else
	{
		[[self messageDisplayContext]
		 performBlock:^{
			 
			 BOOL	isDisplayMocSavedOk = NO;
			 NSError *displayMocSaveError = nil;
			 
			 isDisplayMocSavedOk =
				 [[self messageDisplayContext] save:&displayMocSaveError];

			 // clear off display MOC to accept new connection
			 if(flushDisplayContext)
			 {
				 [[self messageDisplayContext] reset];
			 }

			 // we are still at main thread
			 if(aMainThreadBlock != NULL)
			 {
				 // whether message save() gets done ok, or not,
				 // we will report to main thread with the result
				 aMainThreadBlock(displayMocSaveError);
			 }
			 
			 if(!isDisplayMocSavedOk || displayMocSaveError != nil)
			 {
				 MTLog(@"we have a save error on display_q %@"
					   ,[displayMocSaveError localizedFailureReason]);
			 }
			 else
			 {
				 // initialize PSC on disk
				 [[self messageSaveContext]
				  performBlock:^{
					  
					  _messageSaveSizeCount += theSaveDataSize;
					  
					  if(flushDisplayContext || DEFAULT_SAVING_BLOCK_SIZE <= _messageSaveSizeCount)
					  {
						  BOOL	isSaveMocSavedOk = NO;
						  NSError *saveMocSaveError = nil;
						  
						  isSaveMocSavedOk =\
							  [[self messageSaveContext] save:&saveMocSaveError];
						  
						  if(!isSaveMocSavedOk || saveMocSaveError != nil)
						  {
							  MTLog(@"we have a save error on save_q %@"
									,[saveMocSaveError localizedFailureReason]);
						  }
						  else
						  {
							  // clear MOC to save mem
							  [[self messageSaveContext] reset];
						  }
						  _messageSaveSizeCount = 0;
					  }
				  }];
			 }
		 }];
		
		// as soon as save() done on process MOC, clear off all NSManagedObjects(NMO)
		[[self messageProcessContext] reset];
	}
}

//------------------------------------------------------------------------------
#pragma mark - logger transport delegate
//------------------------------------------------------------------------------
- (void)transport:(LoggerTransport *)theTransport
didEstablishConnection:(LoggerConnection *)theConnection
	   clientInfo:(LoggerMessage *)theInfoMessage
{
	dispatch_async(_messageProcessQueue, ^{
		@autoreleasepool
		{
			// run count is 0 based. when there is client info exist,
			// you can increase runcount by client's runcount
			int lastRunCount = 0;
			uLong clientHash = [theConnection clientHash];

			@try
			{
				LoggerClientData *client = \
					[[self messageProcessContext]
					 fetchSingleObjectForEntityName:@"LoggerClientData"
					 withPredicate:
						[NSString stringWithFormat:@"clientHash == %ld",clientHash]
					 ];

				if (client == nil)
				{
					client =\
						[NSEntityDescription
						 insertNewObjectForEntityForName:@"LoggerClientData"
						 inManagedObjectContext:[self messageProcessContext]];

					[client setClientHash:			[NSNumber numberWithUnsignedLong:clientHash]];
					[client setClientName:			[theConnection clientName]];
					[client setClientVersion:		[theConnection clientVersion]];
					[client setClientOSName:		[theConnection clientOSName]];
					[client setClientDevice:		[theConnection clientDevice]];
					[client setClientUDID:			[theConnection clientUDID]];
				}

				// runcount is 0-based 
				lastRunCount = (int)[[client connectionStatus] count];
				
				// @@@ TODO: we should avoid set a client's run count in a connection 
				[theConnection setReconnectionCount:lastRunCount];

				MTLog(@"%s (%lx)[%d]",__PRETTY_FUNCTION__,theConnection.clientHash, theConnection.reconnectionCount);
				
				LoggerConnectionStatusData *status = \
					[NSEntityDescription
					 insertNewObjectForEntityForName:@"LoggerConnectionStatusData"
					 inManagedObjectContext:[self messageProcessContext]];

				[status setClientHash:		[NSNumber numberWithUnsignedLong:clientHash]];
				[status setRunCount:		[NSNumber numberWithInt:lastRunCount]];
				[status setClientAddress:	[theConnection clientAddressDescription]];
				[status setTransportInfo:	[theTransport transportInfoString]];
				[status setStartTime:		[NSNumber numberWithLongLong:mach_absolute_time()]];
				//[status setClientInfo:		client];
				[client addConnectionStatusObject:status];
				
			
				LoggerMessageData *messageData =\
					[NSEntityDescription
					 insertNewObjectForEntityForName:@"LoggerMessageData"
					 inManagedObjectContext:[self messageProcessContext]];

				struct timeval tm = [theInfoMessage timestamp];
				uint64_t tm64 = timetoint64(&tm);
				
				//run count of the connection
				[messageData setClientHash:		[NSNumber numberWithUnsignedLong:clientHash]];
				[messageData setRunCount:		[NSNumber numberWithInt:lastRunCount]];
				
				[messageData setTimestamp:		[NSNumber numberWithUnsignedLongLong:tm64]];
				[messageData setTimestampString:[theInfoMessage timestampString]];
				[messageData setFileFuncRepresentation:[theInfoMessage fileFuncString]];
				
				[messageData setTag:			nil];
				[messageData setFilename:		nil];
				[messageData setFunctionName:	nil];

				[messageData setSequence:		[NSNumber numberWithUnsignedInteger:0]];
				[messageData setThreadID:		nil];
				[messageData setLineNumber:		[NSNumber numberWithInt:0]];
				
				[messageData setLevel:			[NSNumber numberWithShort:0]];
				[messageData setType:			[NSNumber numberWithShort:[theInfoMessage type]]];
				[messageData setContentsType:	[NSNumber numberWithShort:[theInfoMessage contentsType]]];
				[messageData setMessageType:	[theInfoMessage messageType]];
				
				[messageData setPortraitHeight: [NSNumber numberWithFloat:[theInfoMessage portraitHeight]]];
				[messageData setPortraitMessageSize:NSStringFromCGSize([theInfoMessage portraitMessageSize])];
				[messageData setLandscapeHeight:[NSNumber numberWithFloat:[theInfoMessage landscapeHeight]]];
				[messageData setLandscapeMessageSize:NSStringFromCGSize([theInfoMessage landscapeMessageSize])];
				
				
				// formatted text for string message
				[messageData setTextRepresentation:[theInfoMessage textRepresentation]];

			}
			@catch (NSException *exception)
			{
				MTLog(@"CoreData save error! : %@",exception.reason);
			}
			@finally
			{
				// once you say 'yes' to save change for flushing, it doesn't matter
				// how much data you want to save.
				[self
				 _runMessageSaveChain:0
				 flushDisplayContext:YES
				 withMainThreadBlock:^(NSError *saveError){
					 [[LoggerTransportManager sharedTransportManager]
					  presentTransportStatus:
					  @{kClientHash:[NSNumber numberWithUnsignedLong:clientHash]
					  ,kClientRunCount:[NSNumber numberWithInt:lastRunCount]}
					  forKey:kShowClientConnectedNotification];
				}];
			}
		}
	});
}

// method reporting messages to transport maanger
- (void)transport:(LoggerTransport *)theTransport
	   connection:(LoggerConnection *)theConnection
didReceiveMessages:(NSArray *)theMessages
			range:(NSRange)rangeInMessagesList
{
	dispatch_async(_messageProcessQueue, ^{
		@autoreleasepool
		{
			NSUInteger end = [theMessages count];

			// data size to be saved/updated to PSC
			unsigned long dataSaveSize = 0;
			
			@try
			{
				for (int i = 0; i < end; i++)
				{
					LoggerNativeMessage *aMessage = [theMessages objectAtIndex:i];

					LoggerMessageData *messageData =\
						[NSEntityDescription
						 insertNewObjectForEntityForName:@"LoggerMessageData"
						 inManagedObjectContext:[self messageProcessContext]];
					
					struct timeval tm = [aMessage timestamp];
					uint64_t tm64 = timetoint64(&tm);

					//run count of the connection
					[messageData setClientHash:		[NSNumber numberWithUnsignedLong:[theConnection clientHash]]];

					// @@@ TODO: find a way to retrieve client run count from LoggerClientData
					[messageData setRunCount:		[NSNumber numberWithInt:[theConnection reconnectionCount]]];

					[messageData setTimestamp:		[NSNumber numberWithUnsignedLongLong:tm64]];
					[messageData setTimestampString:[aMessage timestampString]];

					[messageData setTag:			[aMessage tag]];
					[messageData setFilename:		[aMessage filename]];
					[messageData setFunctionName:	[aMessage functionName]];
					[messageData setFileFuncRepresentation:[aMessage fileFuncString]];
					
					[messageData setSequence:		[NSNumber numberWithUnsignedInteger:[aMessage sequence]]];
					[messageData setThreadID:		[aMessage threadID]];
					[messageData setLineNumber:		[NSNumber numberWithInt:[aMessage lineNumber]]];
					
					[messageData setLevel:			[NSNumber numberWithShort:[aMessage level]]];
					[messageData setType:			[NSNumber numberWithShort:[aMessage type]]];
					[messageData setContentsType:	[NSNumber numberWithShort:[aMessage contentsType]]];
					[messageData setMessageType:	[aMessage messageType]];

					[messageData setPortraitFileFuncHeight:[NSNumber numberWithFloat:[aMessage portraitFileFuncHeight]]];
					[messageData setPortraitHeight: [NSNumber numberWithFloat:[aMessage portraitHeight]]];
					[messageData setPortraitMessageSize:NSStringFromCGSize([aMessage portraitMessageSize])];

					[messageData setLandscapeFileFuncHeight:[NSNumber numberWithFloat:[aMessage landscaleFileFuncHeight]]];
					[messageData setLandscapeHeight:[NSNumber numberWithFloat:[aMessage landscapeHeight]]];
					[messageData setLandscapeMessageSize:NSStringFromCGSize([aMessage landscapeMessageSize])];

					//now store datas
					switch ([aMessage contentsType])
					{
						case kMessageString:{
							
							// formatted text for string message
							[messageData setTextRepresentation:[aMessage textRepresentation]];

							// save full text
							[messageData setMessageText:[aMessage messageText]];

							[messageData setTruncated:[NSNumber numberWithBool:[aMessage isTruncated]]];
							
							// set hint size
							if([aMessage isTruncated])
							{
								[messageData setPortraitHintHeight:[NSNumber numberWithFloat:[aMessage portraitHintHeight]]];
								[messageData setLandscapeHintHeight:[NSNumber numberWithFloat:[aMessage landscapeHintHeight]]];
							}
							break;
						}
							
						case kMessageData:{

							// formatted text for binary message
							[messageData setTextRepresentation:[aMessage textRepresentation]];
							
							[messageData setTruncated:[NSNumber numberWithBool:[aMessage isTruncated]]];
							
							// set hint size
							if([aMessage isTruncated])
							{
								[messageData setPortraitHintHeight:[NSNumber numberWithFloat:[aMessage portraitHintHeight]]];
								[messageData setLandscapeHintHeight:[NSNumber numberWithFloat:[aMessage landscapeHintHeight]]];
							}

							
							// filepath is made of 'client hash'/'run count'/'timestamp.data'
							NSString *filepath = \
								[NSString stringWithFormat:@"%lx/%d/%llx.data"
								 ,[theConnection clientHash]
								 ,[theConnection reconnectionCount]
								 ,tm64];
							
							// data filepath
							[messageData setDataFilepath:filepath];
							
							[[self dataStorage]
							 writeData:[aMessage message]
							 toPath:filepath
							 forType:kMessageData];


							break;
						}
							
						case kMessageImage:{

							// set image size
							[messageData setImageSize:NSStringFromCGSize([aMessage imageSize])];
							
							
							// filepath is made of 'client hash'/'run count'/'timestamp.data'
							NSString *filepath = \
								[NSString stringWithFormat:@"%lx/%d/%llx.image"
								 ,[theConnection clientHash]
								 ,[theConnection reconnectionCount]
								 ,tm64];

							// image filepath
							[messageData setDataFilepath:filepath];

							[[self dataStorage]
							 writeData:[aMessage message]
							 toPath:filepath
							 forType:kMessageImage];
							
							break;
						}
						default:
							break;
					}
					
					
					dataSaveSize += [messageData rawDataSize];
				}
				
			}
			@catch (NSException *exception)
			{
				MTLog(@"CoreData save error! : %@",exception.reason);
			}
			@finally
			{
				// since we've completed copying messages into coredata,
				[self _runMessageSaveChain:dataSaveSize
				 withMainThreadBlock:NULL];
			}
		}
	});
}

// method reporting to transport manager
- (void)transport:(LoggerTransport *)theTransport
didDisconnectRemote:(LoggerConnection *)theConnection
	  lastMessage:(LoggerMessage *)theLastMessage
{
	// handle disconnection specific logic
	dispatch_async(_messageProcessQueue, ^{
		@autoreleasepool {

			MTLog(@"transport:didDisconnectRemote: (%lx)[%d]",theConnection.clientHash, theConnection.reconnectionCount);
			
			uLong clientHash = [theConnection clientHash];
			int32_t lastRunCount = [theConnection reconnectionCount];
			@try
			{
				// run count is 0 based. when there is client info exist,
				// you can increase runcount by client's runcount
				LoggerConnectionStatusData *status = \
					[[self messageProcessContext]
					 fetchSingleObjectForEntityName:@"LoggerConnectionStatusData"
					 withPredicate:
					 [NSString
					  stringWithFormat:@"clientHash == %ld AND runCount == %d"
					  ,clientHash
					  ,lastRunCount]];
				
				// connection status info cannot be nil. if it is, we are in trouble
				assert(status != nil);
				
				struct timeval tm = [theLastMessage timestamp];
				uint64_t tm64 = timetoint64(&tm);
				
				[status setEndTime:[NSNumber numberWithUnsignedLongLong:tm64]];
				
				LoggerMessageData *messageData =\
					[NSEntityDescription
					 insertNewObjectForEntityForName:@"LoggerMessageData"
					 inManagedObjectContext:[self messageProcessContext]];
				
				//run count of the connection
				[messageData setClientHash:		[NSNumber numberWithUnsignedLong:[theConnection clientHash]]];
				[messageData setRunCount:		[NSNumber numberWithInt:[theConnection reconnectionCount]]];
				
				[messageData setTimestamp:		[NSNumber numberWithUnsignedLongLong:tm64]];
				[messageData setTimestampString:[theLastMessage timestampString]];
				
				[messageData setTag:			nil];
				[messageData setFilename:		nil];
				[messageData setFunctionName:	nil];
				
				[messageData setSequence:		[NSNumber numberWithUnsignedInteger:[theLastMessage sequence]]];
				[messageData setThreadID:		nil];
				[messageData setLineNumber:		[NSNumber numberWithInt:0]];
				
				[messageData setLevel:			[NSNumber numberWithShort:0]];
				[messageData setType:			[NSNumber numberWithShort:[theLastMessage type]]];
				[messageData setContentsType:	[NSNumber numberWithShort:[theLastMessage contentsType]]];
				[messageData setMessageType:	[theLastMessage messageType]];
				
				[messageData setPortraitHeight: [NSNumber numberWithFloat:[theLastMessage portraitHeight]]];
				[messageData setPortraitMessageSize:NSStringFromCGSize([theLastMessage portraitMessageSize])];
				[messageData setLandscapeHeight:[NSNumber numberWithFloat:[theLastMessage landscapeHeight]]];
				[messageData setLandscapeMessageSize:NSStringFromCGSize([theLastMessage landscapeMessageSize])];
				
				// formatted text for string message
				[messageData setTextRepresentation:[theLastMessage textRepresentation]];

			}
			@catch (NSException *exception)
			{
				MTLog(@"CoreData save error! : %@",exception.reason);
			}
			@finally
			{
				// when connection gets finished, flush off processing/saving MOC of NMOs
				[self _runMessageSaveChain:(DEFAULT_SAVING_BLOCK_SIZE + 1)
				 withMainThreadBlock:^(NSError *saveError){
					[[LoggerTransportManager sharedTransportManager]
					 presentTransportStatus:
						 @{kClientHash:[NSNumber numberWithUnsignedLong:clientHash]
						 ,kClientRunCount:[NSNumber numberWithInt:lastRunCount]}
					 forKey:kShowClientDisconnectedNotification];
				}];
			}
		}
	});
}

- (void)transport:(LoggerTransport *)theTransport
 removeConnection:(LoggerConnection *)theConnection
{
	
}
@end
