/*
 *
 * Modified BSD license.
 *
 * Based on source code
 * Copyright 2007 Matt Gallagher. All rights reserved.
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


#import "NSManagedObjectContext+FetchAdditions.h"

@implementation NSManagedObjectContext (FetchAdditions)
//
// fetchObjectSetForRequest:
//
// Convenience method to issue a fetch request on the receiver, gather the
// results and return them as a set.
//
- (NSSet *)fetchObjectSetForRequest:(NSFetchRequest *)request
{
	NSError *error = nil;
	NSArray *results = [self executeFetchRequest:request error:&error];
	
	MTAssert(error == nil, @"%@", [error description]);
	
	return [NSSet setWithArray:results];
}

//
// fetchObjectArrayForRequest:
//
// Convenience method to issue a fetch request on the receiver, gather the
// results and return them as a set.
//
- (NSArray *)fetchObjectArrayForRequest:(NSFetchRequest *)request
{
	NSError *error = nil;
	NSArray *results = [self executeFetchRequest:request error:&error];
	
	MTAssert(error == nil, @"%@", [error description]);
	
	return results;
}

//
// fetchRequestForEntityName:
//
// Convenience method that builds a fetch request for the specified entity
// named, where the entity name is resolved in the receiver.
//
- (NSFetchRequest *)fetchRequestForEntityName:(NSString *)newEntityName
{
	NSEntityDescription *entity =
		[NSEntityDescription
			entityForName:newEntityName
			inManagedObjectContext:self];
	MTAssert(entity, @"Entity not found for entity name %@", newEntityName);

	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:entity];
	
	return request;
}

//
// fetchRequestForEntityName:withPredicate:
//
// Convenience method that builds a fetch request for the specified entity
// named, where the entity name is resolved in the receiver.
//
- (NSFetchRequest *)fetchRequestForEntityName:(NSString *)newEntityName
	withPredicate:(id)stringOrPredicate, ...
{
	NSFetchRequest *request =
		[self fetchRequestForEntityName:newEntityName];
	
	if (stringOrPredicate)
	{
		NSPredicate *predicate;
		if ([stringOrPredicate isKindOfClass:[NSString class]])
		{
			va_list variadicArguments;
			va_start(variadicArguments, stringOrPredicate);
			predicate =
				[NSPredicate
					predicateWithFormat:stringOrPredicate
					arguments:variadicArguments];
			va_end(variadicArguments);
		}
		else
		{
			MTAssert([stringOrPredicate isKindOfClass:[NSPredicate class]],
				@"Second parameter passed to %s is of unexpected class %@",
				sel_getName(_cmd), NSStringFromClass(stringOrPredicate));
			predicate = (NSPredicate *)stringOrPredicate;
		}
		[request setPredicate:predicate];
	}
	
	return request;
}

//
// fetchObjectSetForEntityName:withPredicate:
//
// Convenience method to fetch the array of entities for a given name in
// the context, optionally limiting by a predicate.
//
- (NSSet *)fetchObjectSetForEntityName:(NSString *)newEntityName
	withPredicate:(id)stringOrPredicate, ...
{
	NSFetchRequest *request =
		[self fetchRequestForEntityName:newEntityName];
	
	if (stringOrPredicate)
	{
		NSPredicate *predicate;
		if ([stringOrPredicate isKindOfClass:[NSString class]])
		{
			va_list variadicArguments;
			va_start(variadicArguments, stringOrPredicate);
			predicate =
				[NSPredicate
					predicateWithFormat:stringOrPredicate
					arguments:variadicArguments];
			va_end(variadicArguments);
		}
		else
		{
			MTAssert([stringOrPredicate isKindOfClass:[NSPredicate class]],
				@"Second parameter passed to %s is of unexpected class %@",
				sel_getName(_cmd), NSStringFromClass(stringOrPredicate));
			predicate = (NSPredicate *)stringOrPredicate;
		}
		[request setPredicate:predicate];
	}

	return [self fetchObjectSetForRequest:request];
}

//
// fetchObjectArrayForEntityName:withPredicate:
//
// Convenience method to fetch the array of entities for a given name in
// the context, optionally limiting by a predicate.
//
- (NSArray *)fetchObjectArrayForEntityName:(NSString *)newEntityName
	withPredicate:(id)stringOrPredicate, ...
{
	NSFetchRequest *request =
		[self fetchRequestForEntityName:newEntityName];

	if (stringOrPredicate)
	{
		NSPredicate *predicate;
		if ([stringOrPredicate isKindOfClass:[NSString class]])
		{
			va_list variadicArguments;
			va_start(variadicArguments, stringOrPredicate);
			predicate =
				[NSPredicate
					predicateWithFormat:stringOrPredicate
					arguments:variadicArguments];
			va_end(variadicArguments);
		}
		else
		{
			MTAssert([stringOrPredicate isKindOfClass:[NSPredicate class]],
				@"Second parameter passed to %s is of unexpected class %@",
				sel_getName(_cmd), NSStringFromClass(stringOrPredicate));
			predicate = (NSPredicate *)stringOrPredicate;
		}
		[request setPredicate:predicate];
	}

	NSError *error = nil;
	NSArray *results = [self executeFetchRequest:request error:&error];
	
	MTAssert(error == nil, @"%@", [error description]);
	
	return results;
}

//
// fetchSingleObjectForEntityName:withPredicate:
//
// Fetches a single object matching the entity name and predicate. If more than
// one objects found, throws an exception (so don't use this
// haphazardly).
//
// Parameters:
//    newEntityName - entity of the object to fetch
//    stringOrPredicate, - predicate string or predicate to select the object
//    ... - parameters to the predicate string
//
// returns the object found.
//
- (NSManagedObject *)fetchSingleObjectForEntityName:(NSString *)newEntityName
	withPredicate:(id)stringOrPredicate, ...
{
	NSFetchRequest *request =
		[self fetchRequestForEntityName:newEntityName];
	
	if (stringOrPredicate)
	{
		NSPredicate *predicate;
		if ([stringOrPredicate isKindOfClass:[NSString class]])
		{
			va_list variadicArguments;
			va_start(variadicArguments, stringOrPredicate);
			predicate =
				[NSPredicate
					predicateWithFormat:stringOrPredicate
					arguments:variadicArguments];
			va_end(variadicArguments);
		}
		else
		{
			MTAssert([stringOrPredicate isKindOfClass:[NSPredicate class]],
				@"Second parameter passed to %s is of unexpected class %@",
				sel_getName(_cmd), NSStringFromClass(stringOrPredicate));
			predicate = (NSPredicate *)stringOrPredicate;
		}
		[request setPredicate:predicate];
	}

	NSError *error = nil;
	NSArray *results = [self executeFetchRequest:request error:&error];
	
	MTAssert(error == nil, @"%@", [error description]);
	MTAssert([results count] <= 1, @"Object count %lud returned from method %@",
		(unsigned long)[results count], NSStringFromSelector(_cmd));
	
	return [results lastObject];
}

//
// fetchObjectSetForEntityName:prefaultingPaths:withPredicate:
//
// Convenience method to fetch the array of entities for a given name in
// the context, optionally limiting by a predicate.
//
- (NSSet *)fetchObjectSetForEntityName:(NSString *)newEntityName
	prefetchingPaths:(NSArray *)prefetchPaths
	withPredicate:(id)stringOrPredicate, ...
{
	NSFetchRequest *request =
		[self fetchRequestForEntityName:newEntityName];
	[request setRelationshipKeyPathsForPrefetching:prefetchPaths];
	
	if (stringOrPredicate)
	{
		NSPredicate *predicate;
		if ([stringOrPredicate isKindOfClass:[NSString class]])
		{
			va_list variadicArguments;
			va_start(variadicArguments, stringOrPredicate);
			predicate =
				[NSPredicate
					predicateWithFormat:stringOrPredicate
					arguments:variadicArguments];
			va_end(variadicArguments);
		}
		else
		{
			MTAssert([stringOrPredicate isKindOfClass:[NSPredicate class]],
				@"Second parameter passed to %s is of unexpected class %@",
				sel_getName(_cmd), NSStringFromClass(stringOrPredicate));
			predicate = (NSPredicate *)stringOrPredicate;
		}
		[request setPredicate:predicate];
	}

	return [self fetchObjectSetForRequest:request];
}

//
// fetchObjectArrayForEntityName:prefaultingPaths:withPredicate:
//
// Convenience method to fetch the array of entities for a given name in
// the context, optionally limiting by a predicate.
//
- (NSArray *)fetchObjectArrayForEntityName:(NSString *)newEntityName
	prefetchingPaths:(NSArray *)prefetchPaths
	withPredicate:(id)stringOrPredicate, ...
{
	NSFetchRequest *request =
		[self fetchRequestForEntityName:newEntityName];
	[request setRelationshipKeyPathsForPrefetching:prefetchPaths];
	
	if (stringOrPredicate)
	{
		NSPredicate *predicate;
		if ([stringOrPredicate isKindOfClass:[NSString class]])
		{
			va_list variadicArguments;
			va_start(variadicArguments, stringOrPredicate);
			predicate =
				[NSPredicate
					predicateWithFormat:stringOrPredicate
					arguments:variadicArguments];
			va_end(variadicArguments);
		}
		else
		{
			MTAssert([stringOrPredicate isKindOfClass:[NSPredicate class]],
				@"Second parameter passed to %s is of unexpected class %@",
				sel_getName(_cmd), NSStringFromClass(stringOrPredicate));
			predicate = (NSPredicate *)stringOrPredicate;
		}
		[request setPredicate:predicate];
	}

	return [self fetchObjectArrayForRequest:request];
}

//
// objectWithURI:
//
// Convenience method to find the object for the specified URI in the current
// context.
//
- (NSManagedObject *)objectWithURI:(NSURL *)url
{
	NSManagedObjectID *objectID =
		[[self persistentStoreCoordinator]
			managedObjectIDForURIRepresentation:url];
	
	if (!objectID)
	{
		return nil;
	}
	
	NSManagedObject *objectForID = [self objectWithID:objectID];
	if (![objectForID isFault])
	{
		return objectForID;
	}

	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:[objectID entity]];
	NSPredicate *predicate =
		[NSComparisonPredicate
			predicateWithLeftExpression:
				[NSExpression expressionForEvaluatedObject]
			rightExpression:
				[NSExpression expressionForConstantValue:objectForID]
			modifier:NSDirectPredicateModifier
			type:NSEqualToPredicateOperatorType
			options:0];
	[request setPredicate:predicate];
	NSArray *results = [self executeFetchRequest:request error:nil];
	if ([results count] > 0 )
	{
		return [results objectAtIndex:0];
	}

	return nil;
}

- (NSArray *)fetchObjectArrayForEntityName:(NSString *)newEntityName
							  forBatchSize:(NSUInteger)batchSize
								 ascending:(BOOL)isAscending
								 onSortKey:(id)stringOfSortKey
							 withPredicate:(id)stringOrPredicate, ...
{
	NSFetchRequest *request =
	[self fetchRequestForEntityName:newEntityName];

	[request setSortDescriptors:
	 [NSArray arrayWithObject:
	  [NSSortDescriptor sortDescriptorWithKey:stringOfSortKey 
									ascending:isAscending]]
	 ];

    [request setFetchBatchSize:batchSize];
	[request setFetchLimit:batchSize];
	
	
	if (stringOrPredicate)
	{
		NSPredicate *predicate;
		if ([stringOrPredicate isKindOfClass:[NSString class]])
		{
			va_list variadicArguments;
			va_start(variadicArguments, stringOrPredicate);
			predicate =
			[NSPredicate
			 predicateWithFormat:stringOrPredicate
			 arguments:variadicArguments];
			va_end(variadicArguments);
		}
		else
		{
			MTAssert([stringOrPredicate isKindOfClass:[NSPredicate class]],
					 @"Second parameter passed to %s is of unexpected class %@",
					 sel_getName(_cmd), NSStringFromClass(stringOrPredicate));
			predicate = (NSPredicate *)stringOrPredicate;
		}
		[request setPredicate:predicate];
	}
	
	NSError *error = nil;
	NSArray *results = [self executeFetchRequest:request error:&error];
	
	MTAssert(error == nil, @"%@", [error description]);
	
	return results;
}

@end
