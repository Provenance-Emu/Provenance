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



#import "LoggerDataStorage.h"
#import "NullStringCheck.h"
#import "LoggerDataWrite.h"
#import "LoggerDataRead.h"
#import "LoggerDataDelete.h"
#import "LoggerDataEntry.h"
#import "SynthesizeSingleton.h"

#define CHECK_OPERATION_DEPENDENCY
#define DATA_CACHE_PURGE_THRESHOLD	128000

@interface LoggerDataStorage()
@property (nonatomic, readonly) dispatch_queue_t		lowPriorityOperationQueue;
@property (nonatomic, readonly) dispatch_queue_t		highPriorityOperationQueue;
@property (nonatomic, readonly) dispatch_queue_t		operationDispatcherQueue;

@property (nonatomic, readonly) NSMutableDictionary		*dataEntryCache;

@property (nonatomic, readonly) NSMutableArray			*operationPool;
@property (nonatomic, readonly) NSMutableArray			*writeOperationSlot;
@property (nonatomic, readonly) NSMutableArray			*readOperationSlot;

@property (nonatomic, retain)	NSString				*basepath;
@property (nonatomic, readonly) NSUInteger				cpuCount;


-(void)_purgeDataEntryCache;
-(void)_cacheDataEntry:(LoggerDataEntry *)aDataEntry forKey:(NSString *)aKey;
-(void)_checkAccessedDataForPurging:(NSData *)anAccessdData;
-(void)_uncacheDataEntryForKey:(NSString *)aKey;

static inline
unsigned int _write_dependency_count(NSArray*, LoggerDataWrite*);

-(void)_enqueueWriteOperationForData:(NSData *)aData
							  toPath:(NSString *)aFilepath
							 forType:(LoggerMessageType)aType;

static inline
unsigned int _read_dependency_count(NSArray*, LoggerDataRead*);

-(void)_enqueueReadOperationForFile:(NSString *)aFilepath
							forType:(LoggerMessageType)aType
						 withResult:(void (^)(NSData *aData))aResultHandler;

static inline
unsigned int _delete_dependency_count(NSArray*, LoggerDataDelete*);

-(void)_dequeueOperation:(LoggerDataOperation *)anOperation;

-(void)_dispatchOperation:(LoggerDataOperation *)anOperation;
@end

@implementation LoggerDataStorage
{
	// this queue will handle instruction dependency issue,
	// enqueue instruction to instruction queue, and callback to UI-
	dispatch_queue_t		_lowPriorityOperationQueue;
	
	// this queue manages # of concurrent instructions,
	// and instruction queue
	dispatch_queue_t		_highPriorityOperationQueue;

	// according to this count, we will resume or suspend the queue above
	NSUInteger			_high_queue_suspension_count;

	// this queue will concurrently dispatch actual instructions
	dispatch_queue_t		_operationDispatcherQueue;

	// this is the cache pool that contains binary data
	NSMutableDictionary		*_dataEntryCache;
	NSUInteger			_dataEntryCacheSize;
	
	// data operation queue
	NSMutableArray			*_operationPool;
	
	// since we're to operation within instruction queue,
	// we don't want this to be volatile, which would consume more CPU cycles
	// we want this to be non-volatile, confined in a specific queue,
	// and runs blazing fast.
	NSMutableArray			*_readOperationSlot;
	NSMutableArray			*_writeOperationSlot;
	
	// a path where directory operation must based on
	NSString				*_basepath;
	
	NSUInteger				_cpuCount;
}
@synthesize lowPriorityOperationQueue			= _lowPriorityOperationQueue;
@synthesize highPriorityOperationQueue			= _highPriorityOperationQueue;
@synthesize operationDispatcherQueue			= _operationDispatcherQueue;

@synthesize readOperationSlot					= _readOperationSlot;
@synthesize writeOperationSlot					= _writeOperationSlot;

@synthesize operationPool						= _operationPool;

@synthesize dataEntryCache						= _dataEntryCache;

@synthesize basepath							= _basepath;
@synthesize cpuCount							= _cpuCount;

SYNTHESIZE_SINGLETON_FOR_CLASS_WITH_ACCESSOR(LoggerDataStorage,sharedDataStorage);

-(id)init
{
	self = [super init];
	if(self != nil)
	{
		// manages instruction dependency, create instruction, take
		// read/write/delete/purge command from other components
		_lowPriorityOperationQueue =\
			dispatch_queue_create("com.colorfulglue.loggerdatastorage.lowpriorityqueue"
								  ,DISPATCH_QUEUE_SERIAL);
		
		// read/write/delete/purge instruction handling queue
		_highPriorityOperationQueue = \
			dispatch_queue_create("com.colorfulglue.loggerdatastorage.highpriorityqueue"
								  ,DISPATCH_QUEUE_SERIAL);
		
		_high_queue_suspension_count = 1;
		
		// process instruction
		_operationDispatcherQueue = \
			dispatch_queue_create("com.colorfulglue.loggerdatastorage.dispatcherqueue"
								  ,DISPATCH_QUEUE_CONCURRENT);
		
		
		// low priority queue will target high priority
		dispatch_set_target_queue(_lowPriorityOperationQueue,_highPriorityOperationQueue);
		
		// cpu core counts
		NSUInteger cpus = [[NSProcessInfo processInfo] processorCount];
		
		dispatch_sync(_highPriorityOperationQueue, ^{
			
			// grab basePath
			NSArray *paths = \
				NSSearchPathForDirectoriesInDomains(NSDocumentDirectory
													,NSUserDomainMask, YES);
			
			NSString *path = \
				([paths count] > 0) ? [paths objectAtIndex:0] : nil;
			
			NSString *targetPath = \
				(path) ? [NSString stringWithFormat:@"%@/",path] : nil;
			
			_basepath = [targetPath retain];
			
			
			// data cache setup
			_dataEntryCacheSize = 0;
			
			_dataEntryCache = \
				[[NSMutableDictionary alloc] initWithCapacity:0];
			
			
			// operational queue setup
			_cpuCount = cpus;
			
			_operationPool =\
				[[NSMutableArray alloc] initWithCapacity:_cpuCount * 2];
			
			_readOperationSlot =\
				[[NSMutableArray alloc] initWithCapacity:_cpuCount];
			
			_writeOperationSlot = \
				[[NSMutableArray alloc] initWithCapacity:_cpuCount];
		});
	}
	return self;
}

//------------------------------------------------------------------------------
#pragma mark - App life cycle handlers
//------------------------------------------------------------------------------
// when app did start
-(void)appStarted
{
	
}

// app resigned from activity (power button, home button clicked)
-(void)appResignActive
{
	if(0 < _high_queue_suspension_count)
	{
		dispatch_suspend(_highPriorityOperationQueue);
		_high_queue_suspension_count--;
	}
}

// app becomes active again
-(void)appBecomeActive
{
	if(_high_queue_suspension_count <= 0)
	{
		dispatch_resume(_highPriorityOperationQueue);
		_high_queue_suspension_count++;
	}
	
}

// app will terminate
-(void)appWillTerminate
{
	
}

//------------------------------------------------------------------------------
#pragma mark - Write/Read/Delete operation
//------------------------------------------------------------------------------
-(void)writeData:(NSData *)aData
		  toPath:(NSString *)aFilepath
		 forType:(LoggerMessageType)aType
{
	if(IS_NULL_STRING(aFilepath))
		return;

	if(aData == nil || ![aData length])
		return;

	dispatch_async([self highPriorityOperationQueue], ^{
		[self _enqueueWriteOperationForData:aData toPath:aFilepath forType:aType];
	});
}

-(void)readDataFromPath:(NSString *)aPath
				forType:(LoggerMessageType)aType
			 withResult:(void (^)(NSData *aData))aResultHandler
{	
	if(IS_NULL_STRING(aPath))
	{
		aResultHandler(nil);
		return;
	}

	dispatch_async([self lowPriorityOperationQueue], ^{
		
		LoggerDataEntry *entry = [[self dataEntryCache] objectForKey:aPath];
		
		if(entry != nil)
		{
			if([entry data] != nil)
			{
				NSData *cachedData = [entry data];
				aResultHandler(cachedData);
				
				return;
			}
			else
			{
				MTLog(@"this should never happen ! %@",aPath);
				return;
			}
		}

		// cannot find an entry from cache. find it from file system
		dispatch_async([self highPriorityOperationQueue], ^{
			[self _enqueueReadOperationForFile:aPath forType:aType withResult:aResultHandler];
		});
		
	});
}

-(void)deleteWholePath:(NSString *)aPath
{
	dispatch_async([self lowPriorityOperationQueue], ^{
		[self _enqueueDeleteOperationForDir:aPath];
	});
}

//------------------------------------------------------------------------------
#pragma mark - Cache Operation
//------------------------------------------------------------------------------

-(void)_purgeDataEntryCache
{
	dispatch_async([self lowPriorityOperationQueue], ^{
		NSMutableArray *purgeList = \
			[[NSMutableArray alloc] initWithCapacity:0];

		unsigned int totalPurgedDataSize = 0;

		for (NSString *key in _dataEntryCache)
		{
			LoggerDataEntry *entry = [_dataEntryCache objectForKey:key];
			if([[entry dataOperations] count] == 0)
			{
				[purgeList addObject:key];
				totalPurgedDataSize += [entry totalDataLength];
			}
		}

		// remove purge list
		[_dataEntryCache removeObjectsForKeys:purgeList];
		[purgeList release],purgeList = nil;
		_dataEntryCacheSize -= totalPurgedDataSize;
	});
}

-(void)_cacheDataEntry:(LoggerDataEntry *)aDataEntry forKey:(NSString *)aKey
{
	[[self dataEntryCache] setObject:aDataEntry forKey:aKey];
	_dataEntryCacheSize += [aDataEntry totalDataLength];
	if(DATA_CACHE_PURGE_THRESHOLD <= _dataEntryCacheSize )
	{
		// start purging cache
		[self _purgeDataEntryCache];
	}
}

-(void)_checkAccessedDataForPurging:(NSData *)anAccessdData
{
	_dataEntryCacheSize += [anAccessdData length];
	if(DATA_CACHE_PURGE_THRESHOLD <= _dataEntryCacheSize )
	{
		// start purging cache
		[self _purgeDataEntryCache];
	}
}

-(void)_uncacheDataEntryForKey:(NSString *)aKey
{
	LoggerDataEntry *entry = [[self dataEntryCache] objectForKey:aKey];
	_dataEntryCacheSize -= [entry totalDataLength];
	[[self dataEntryCache] removeObjectForKey:aKey];
}



//------------------------------------------------------------------------------
#pragma mark - Enqueue operations
//------------------------------------------------------------------------------
static inline
unsigned int _write_dependency_count(NSArray *pool, LoggerDataWrite *operation)
{
	__block unsigned int dependencies = 0;

	// check operation dependency
	if([pool count])
	{
		[pool enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
		{

			LoggerDataOperation *dataOp =  (LoggerDataOperation *)obj;

			// if dataOp is same class, don't count it.
			if([dataOp class] == [LoggerDataWrite class])
				return;
			
			// delete-write dependency
			//if([dataOp class] == [LoggerDataDelete class]])
			if([dataOp isKindOfClass:[LoggerDataDelete class]])
			{
				if(strcmp(dataOp.dirPartOfFilepath.UTF8String,operation.dirPartOfFilepath.UTF8String) == 0)
				{
					dependencies++;
					return;
				}
			}
			
			//read-write dependency
			if([dataOp isKindOfClass:[LoggerDataRead class]])
			{
				if(strcmp(dataOp.filepath.UTF8String,operation.filepath.UTF8String) == 0)
				{
					dependencies++;
					return;
				}
			}
			
		}];

	}
	
	return dependencies;
}

-(void)_enqueueWriteOperationForData:(NSData *)aData
							  toPath:(NSString *)aFilepath
							 forType:(LoggerMessageType)aType
{
	assert(dispatch_get_current_queue() == [self highPriorityOperationQueue]);

	unsigned int dependencyCount = 0;
	
	LoggerDataEntry *dataEntry = \
		[[LoggerDataEntry alloc] initWithFilepath:aFilepath type:aType];
	
	[dataEntry setData:aData];

	// set cache entry for filepath
	[self _cacheDataEntry:dataEntry forKey:aFilepath];

	LoggerDataWrite	*writeOperation = \
		[[LoggerDataWrite alloc]
		 initWithData:[dataEntry data]
		 basepath:[self basepath]
		 filePath:[dataEntry filepath]
		 dirPartOfFilepath:[dataEntry dirOfFilepath]
		 callback_queue:[self highPriorityOperationQueue]
		 callback:^(LoggerDataOperation *dataOperation, int error, NSData *data) {

			 [[dataEntry dataOperations] removeObject:dataOperation];

			 // remove data type data entry from cache immediately after saved
			 if([dataEntry dataType] == kMessageData)
			 {
				 [self _uncacheDataEntryForKey:aFilepath];
			 }
			 
			 [self _dequeueOperation:dataOperation];
		 }];
	
	// check operation dependency
	dependencyCount = _write_dependency_count([self operationPool], writeOperation);
	
	[writeOperation setDependencyCount:dependencyCount];

	// add this operation to dataOperation of anEntry
	[[dataEntry dataOperations] addObject:writeOperation];

	// add operation to pool
	[[self operationPool] addObject:writeOperation];
	
	// if there is no dependency, try to dispatch the operation
	if(dependencyCount == 0)
	{
		[self _dispatchOperation:writeOperation];
	}

	[dataEntry release],dataEntry = nil;
	[writeOperation release],writeOperation = nil;
}

static inline
unsigned int _read_dependency_count(NSArray *pool, LoggerDataRead *operation)
{
	__block unsigned int dependencies = 0;
	
	// check operation dependency
	if([pool count])
	{
		[pool enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
		 {
			 LoggerDataOperation *dataOp =  (LoggerDataOperation *)obj;
			 
			 // if dataOp is same class, don't count it.
			 if([dataOp class] == [LoggerDataRead class])
				 return;

			 // delete-read dependency
			 if([dataOp isKindOfClass:[LoggerDataDelete class]])
			 {
				 if(strcmp(dataOp.dirPartOfFilepath.UTF8String,operation.dirPartOfFilepath.UTF8String) == 0)
				 {
					 dependencies++;
					 return;
				 }
			 }
			 
			 //write-read dependency
			 if([dataOp isKindOfClass:[LoggerDataRead class]])
			 {
				 if(strcmp(dataOp.filepath.UTF8String,operation.filepath.UTF8String) == 0)
				 {
					 dependencies++;
					 return;
				 }
			 }
		 }];
		
	}
	
	return dependencies;
}

-(void)_enqueueReadOperationForFile:(NSString *)aFilepath
							forType:(LoggerMessageType)aType
						 withResult:(void (^)(NSData *aData))aResultHandler
{
	assert(dispatch_get_current_queue() == [self highPriorityOperationQueue]);
	
	unsigned int dependencyCount = 0;
	
	LoggerDataEntry *dataEntry =\
		[[LoggerDataEntry alloc] initWithFilepath:aFilepath type:aType];
	
	// set cache entry for filepath
	[self _cacheDataEntry:dataEntry forKey:aFilepath];

	LoggerDataRead	*readOperation = \
		[[LoggerDataRead alloc]
		 initWithBasepath:[self basepath]
		 filePath:[dataEntry filepath]
		 dirOfFilepath:[dataEntry dirOfFilepath]
		 callback_queue:[self highPriorityOperationQueue]
		 callback:^(LoggerDataOperation *dataOperation, int error, NSData *data) {
			 
			if(error == 0)
			{
				// retain accesed data
				[dataEntry setData:data];

				// handle success
				aResultHandler(data);
				[[dataEntry dataOperations] removeObject:dataOperation];

				// check if it's neccessary to purge data cache
				[self _checkAccessedDataForPurging:data];
			}
			else
			{
				// if read operation fails, remove datacache
				aResultHandler(nil);
				[self _uncacheDataEntryForKey:aFilepath];
			}

			[self _dequeueOperation:dataOperation];

		 }];

	// check operation dependency
	dependencyCount = _read_dependency_count([self operationPool], readOperation);

	
	[readOperation setDependencyCount:dependencyCount];
	

	// add this operation to dataOperation of anEntry
	[[dataEntry dataOperations] addObject:readOperation];
	
	// add operation to pool
	[[self operationPool] addObject:readOperation];
	
	// if there is no dependency, try to dispatch the operation
	if(dependencyCount == 0)
	{
		[self _dispatchOperation:readOperation];
	}

	[dataEntry release],dataEntry = nil;
	[readOperation release],readOperation = nil;
}

static inline
unsigned int _delete_dependency_count(NSArray *pool, LoggerDataDelete *operation)
{
	__block unsigned int dependencies = 0;
	
	// check operation dependency
	if([pool count])
	{
		[pool enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
		 {
			 LoggerDataOperation *dataOp =  (LoggerDataOperation *)obj;
			 
			 // read,write-delete dependency
			 if(![dataOp isKindOfClass:[LoggerDataDelete class]])
			 {
				 if(strcmp(dataOp.dirPartOfFilepath.UTF8String,operation.dirPartOfFilepath.UTF8String) == 0)
				 {
					 dependencies++;
					 return;
				 }
			 }
		 }];
	}
	
	return dependencies;
}


-(void)_enqueueDeleteOperationForDir:(NSString *)aDirPath
{
	assert(dispatch_get_current_queue() == [self lowPriorityOperationQueue]);

	unsigned int dependencyCount = 0;
	
	LoggerDataDelete *deleteOperation = \
		[[LoggerDataDelete alloc]
		 initWithBasepath:[self basepath]
		 dirOfFilepath:aDirPath
		 callback_queue:[self highPriorityOperationQueue]
		 callback:^(LoggerDataOperation *dataOperation, int error, NSData *data) {
			 
			 [self _dequeueOperation:dataOperation];
 
		 }];

	// check operation dependency
	dependencyCount = _delete_dependency_count([self operationPool], deleteOperation);
	
	[deleteOperation setDependencyCount:dependencyCount];

	[[self operationPool] addObject:deleteOperation];

	// if there is no dependency, try to dispatch the operation
	if(dependencyCount == 0)
	{
		[self _dispatchOperation:deleteOperation];
	}

	[deleteOperation release],deleteOperation = nil;

}


//------------------------------------------------------------------------------
#pragma mark - Dequeue operations
//------------------------------------------------------------------------------
-(void)_dequeueOperation:(LoggerDataOperation *)anOperation
{
	assert(dispatch_get_current_queue() == [self highPriorityOperationQueue]);
	
	// first retain the operation for a while
	[anOperation retain];
	
	// remove the operation from exec slot
	if([anOperation isKindOfClass:[LoggerDataRead class]])
	{
		[[self readOperationSlot] removeObject:anOperation];
	}
	else
	{
		[[self writeOperationSlot] removeObject:anOperation];
	}
	
	// remove from pool
	[[self operationPool] removeObject:anOperation];
	
	// search next operation & check dependent operations
	__block LoggerDataOperation *nextOperation = nil;
	
	if([[self operationPool] count])
	{
		for(LoggerDataOperation *dataOp in [self operationPool])
		{
			 // check operation dependency, reduce dependency count by one
			if([dataOp class] != [anOperation class])
			{
				if([dataOp isKindOfClass:[LoggerDataDelete class]] || [anOperation isKindOfClass:[LoggerDataDelete class]])
				{
					if(strcmp(dataOp.dirPartOfFilepath.UTF8String,anOperation.dirPartOfFilepath.UTF8String) == 0)
					{
						unsigned int dependency = [dataOp dependencyCount];
						dependency--;
						[dataOp setDependencyCount:dependency];
					}
				}
				else
				{
					if(strcmp(dataOp.filepath.UTF8String, anOperation.filepath.UTF8String) == 0)
					{
						unsigned int dependency = [dataOp dependencyCount];
						dependency--;
						[dataOp setDependencyCount:dependency];
					}
				}
			}

			/* condition for finding the next operation is...
			* 1) next target is not found
			* 2) operation's dependency is 0
			* 3) an operatin is not executing
			*/

			if(nextOperation == nil &&
				![dataOp isExecuting] &&
				([dataOp dependencyCount] == 0))
			{
				nextOperation = [dataOp retain];
			}
		}
	}

	// now operation is done with its job. release it
	[anOperation release];
	
	// if there is no dependency and read|write op slot is available,
	// execute the next operation
	if((nextOperation != nil) && (nextOperation.dependencyCount == 0))
	{

		[self _dispatchOperation:nextOperation];

		[nextOperation release],nextOperation = nil;
	}
}

//------------------------------------------------------------------------------
#pragma mark - Dequeue operations
//------------------------------------------------------------------------------
-(void)_dispatchOperation:(LoggerDataOperation *)anOperation
{
	//assert(dispatch_get_current_queue() == [self highPriorityOperationQueue]);

	if([anOperation isKindOfClass:[LoggerDataRead class]])
	{
		if([[self readOperationSlot] count] < [self cpuCount])
		{
			[[self readOperationSlot] addObject:anOperation];
			[anOperation setExecuting:YES];
			[anOperation executeOnQueue:[self operationDispatcherQueue]];
		}
	}
	else
	{
		if([[self writeOperationSlot] count] < [self cpuCount])
		{
			[[self writeOperationSlot] addObject:anOperation];
			[anOperation setExecuting:YES];
			[anOperation executeOnQueue:[self operationDispatcherQueue]];
		}
	}
}


@end
