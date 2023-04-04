/*******************************************************************************
 * The MIT License (MIT)
 * 
 * Copyright (c) 2015 Jean-David Gadina - www.xs-labs.com / www.digidna.net
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

/*!
 * @copyright   (c) 2015 - Jean-David Gadina - www.xs-labs.com / www.digidna.net
 * @brief       ...
 */

#ifndef OBJCXX_H
#define OBJCXX_H

#include <OBJCXX/RT.hpp>
#include <OBJCXX/Object.hpp>
#include <OBJCXX/MethodSignature.hpp>
#include <OBJCXX/ClassBuilder.hpp>

#include <OBJCXX/Foundation/Types.hpp>
#include <OBJCXX/Foundation/Functions.hpp>

#include <OBJCXX/Foundation/Protocols/NSCacheDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSCoding.hpp>
#include <OBJCXX/Foundation/Protocols/NSComparisonMethods.hpp>
#include <OBJCXX/Foundation/Protocols/NSConnectionDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSCopying.hpp>
#include <OBJCXX/Foundation/Protocols/NSDecimalNumberBehaviors.hpp>
#include <OBJCXX/Foundation/Protocols/NSDiscardableContent.hpp>
#include <OBJCXX/Foundation/Protocols/NSErrorRecoveryAttempting.hpp>
#include <OBJCXX/Foundation/Protocols/NSExtensionRequestHandling.hpp>
#include <OBJCXX/Foundation/Protocols/NSFastEnumeration.hpp>
#include <OBJCXX/Foundation/Protocols/NSFileManagerDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSFilePresenter.hpp>
#include <OBJCXX/Foundation/Protocols/NSKeyedArchiverDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSKeyedUnarchiverDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSKeyValueCoding.hpp>
#include <OBJCXX/Foundation/Protocols/NSKeyValueObserving.hpp>
#include <OBJCXX/Foundation/Protocols/NSLocking.hpp>
#include <OBJCXX/Foundation/Protocols/NSMachPortDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSMetadataQueryDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSMutableCopying.hpp>
#include <OBJCXX/Foundation/Protocols/NSNetServiceBrowserDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSNetServiceDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSObject.hpp>
#include <OBJCXX/Foundation/Protocols/NSPortDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSProgressReporting.hpp>
#include <OBJCXX/Foundation/Protocols/NSScriptingComparisonMethods.hpp>
#include <OBJCXX/Foundation/Protocols/NSScriptKeyValueCoding.hpp>
#include <OBJCXX/Foundation/Protocols/NSScriptObjectSpecifiers.hpp>
#include <OBJCXX/Foundation/Protocols/NSSecureCoding.hpp>
#include <OBJCXX/Foundation/Protocols/NSSpellServerDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSStreamDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSURLAuthenticationChallengeSender.hpp>
#include <OBJCXX/Foundation/Protocols/NSURLConnectionDataDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSURLConnectionDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSURLConnectionDownloadDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSURLDownloadDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSURLHandleClient.hpp>
#include <OBJCXX/Foundation/Protocols/NSURLProtocolClient.hpp>
#include <OBJCXX/Foundation/Protocols/NSURLSessionDataDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSURLSessionDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSURLSessionDownloadDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSURLSessionStreamDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSURLSessionTaskDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSUserActivityDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSUserNotificationCenterDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSXMLParserDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSXPCListenerDelegate.hpp>
#include <OBJCXX/Foundation/Protocols/NSXPCProxyCreating.hpp>

#include <OBJCXX/Foundation/Classes/NSAffineTransform.hpp>
#include <OBJCXX/Foundation/Classes/NSAppleEventDescriptor.hpp>
#include <OBJCXX/Foundation/Classes/NSAppleEventManager.hpp>
#include <OBJCXX/Foundation/Classes/NSAppleScript.hpp>
#include <OBJCXX/Foundation/Classes/NSArchiver.hpp>
#include <OBJCXX/Foundation/Classes/NSArray.hpp>
#include <OBJCXX/Foundation/Classes/NSAssertionHandler.hpp>
#include <OBJCXX/Foundation/Classes/NSAttributedString.hpp>
#include <OBJCXX/Foundation/Classes/NSAutoreleasePool.hpp>
#include <OBJCXX/Foundation/Classes/NSBackgroundActivityScheduler.hpp>
#include <OBJCXX/Foundation/Classes/NSBlockOperation.hpp>
#include <OBJCXX/Foundation/Classes/NSBundle.hpp>
#include <OBJCXX/Foundation/Classes/NSByteCountFormatter.hpp>
#include <OBJCXX/Foundation/Classes/NSCache.hpp>
#include <OBJCXX/Foundation/Classes/NSCachedURLResponse.hpp>
#include <OBJCXX/Foundation/Classes/NSCalendar.hpp>
#include <OBJCXX/Foundation/Classes/NSCalendarDate.hpp>
#include <OBJCXX/Foundation/Classes/NSCharacterSet.hpp>
#include <OBJCXX/Foundation/Classes/NSClassDescription.hpp>
#include <OBJCXX/Foundation/Classes/NSCloneCommand.hpp>
#include <OBJCXX/Foundation/Classes/NSCloseCommand.hpp>
#include <OBJCXX/Foundation/Classes/NSCoder.hpp>
#include <OBJCXX/Foundation/Classes/NSComparisonPredicate.hpp>
#include <OBJCXX/Foundation/Classes/NSCompoundPredicate.hpp>
#include <OBJCXX/Foundation/Classes/NSCondition.hpp>
#include <OBJCXX/Foundation/Classes/NSConditionLock.hpp>
#include <OBJCXX/Foundation/Classes/NSConnection.hpp>
#include <OBJCXX/Foundation/Classes/NSCountCommand.hpp>
#include <OBJCXX/Foundation/Classes/NSCountedSet.hpp>
#include <OBJCXX/Foundation/Classes/NSCreateCommand.hpp>
#include <OBJCXX/Foundation/Classes/NSData.hpp>
#include <OBJCXX/Foundation/Classes/NSDataDetector.hpp>
#include <OBJCXX/Foundation/Classes/NSDate.hpp>
#include <OBJCXX/Foundation/Classes/NSDateComponents.hpp>
#include <OBJCXX/Foundation/Classes/NSDateComponentsFormatter.hpp>
#include <OBJCXX/Foundation/Classes/NSDateFormatter.hpp>
#include <OBJCXX/Foundation/Classes/NSDateIntervalFormatter.hpp>
#include <OBJCXX/Foundation/Classes/NSDecimalNumber.hpp>
#include <OBJCXX/Foundation/Classes/NSDecimalNumberHandler.hpp>
#include <OBJCXX/Foundation/Classes/NSDeleteCommand.hpp>
#include <OBJCXX/Foundation/Classes/NSDictionary.hpp>
#include <OBJCXX/Foundation/Classes/NSDirectoryEnumerator.hpp>
#include <OBJCXX/Foundation/Classes/NSDistantObject.hpp>
#include <OBJCXX/Foundation/Classes/NSDistantObjectRequest.hpp>
#include <OBJCXX/Foundation/Classes/NSDistributedLock.hpp>
#include <OBJCXX/Foundation/Classes/NSDistributedNotificationCenter.hpp>
#include <OBJCXX/Foundation/Classes/NSEnergyFormatter.hpp>
#include <OBJCXX/Foundation/Classes/NSEnumerator.hpp>
#include <OBJCXX/Foundation/Classes/NSError.hpp>
#include <OBJCXX/Foundation/Classes/NSException.hpp>
#include <OBJCXX/Foundation/Classes/NSExistsCommand.hpp>
#include <OBJCXX/Foundation/Classes/NSExpression.hpp>
#include <OBJCXX/Foundation/Classes/NSExtensionContext.hpp>
#include <OBJCXX/Foundation/Classes/NSExtensionItem.hpp>
#include <OBJCXX/Foundation/Classes/NSFileAccessIntent.hpp>
#include <OBJCXX/Foundation/Classes/NSFileCoordinator.hpp>
#include <OBJCXX/Foundation/Classes/NSFileHandle.hpp>
#include <OBJCXX/Foundation/Classes/NSFileManager.hpp>
#include <OBJCXX/Foundation/Classes/NSFileSecurity.hpp>
#include <OBJCXX/Foundation/Classes/NSFileVersion.hpp>
#include <OBJCXX/Foundation/Classes/NSFileWrapper.hpp>
#include <OBJCXX/Foundation/Classes/NSFormatter.hpp>
#include <OBJCXX/Foundation/Classes/NSGarbageCollector.hpp>
#include <OBJCXX/Foundation/Classes/NSGetCommand.hpp>
#include <OBJCXX/Foundation/Classes/NSHashTable.hpp>
#include <OBJCXX/Foundation/Classes/NSHost.hpp>
#include <OBJCXX/Foundation/Classes/NSHTTPCookie.hpp>
#include <OBJCXX/Foundation/Classes/NSHTTPCookieStorage.hpp>
#include <OBJCXX/Foundation/Classes/NSHTTPURLResponse.hpp>
#include <OBJCXX/Foundation/Classes/NSIndexPath.hpp>
#include <OBJCXX/Foundation/Classes/NSIndexSet.hpp>
#include <OBJCXX/Foundation/Classes/NSIndexSpecifier.hpp>
#include <OBJCXX/Foundation/Classes/NSInputStream.hpp>
#include <OBJCXX/Foundation/Classes/NSInvocation.hpp>
#include <OBJCXX/Foundation/Classes/NSInvocationOperation.hpp>
#include <OBJCXX/Foundation/Classes/NSItemProvider.hpp>
#include <OBJCXX/Foundation/Classes/NSJSONSerialization.hpp>
#include <OBJCXX/Foundation/Classes/NSKeyedArchiver.hpp>
#include <OBJCXX/Foundation/Classes/NSKeyedUnarchiver.hpp>
#include <OBJCXX/Foundation/Classes/NSLengthFormatter.hpp>
#include <OBJCXX/Foundation/Classes/NSLinguisticTagger.hpp>
#include <OBJCXX/Foundation/Classes/NSLocale.hpp>
#include <OBJCXX/Foundation/Classes/NSLock.hpp>
#include <OBJCXX/Foundation/Classes/NSLogicalTest.hpp>
#include <OBJCXX/Foundation/Classes/NSMachBootstrapServer.hpp>
#include <OBJCXX/Foundation/Classes/NSMachPort.hpp>
#include <OBJCXX/Foundation/Classes/NSMapTable.hpp>
#include <OBJCXX/Foundation/Classes/NSMassFormatter.hpp>
#include <OBJCXX/Foundation/Classes/NSMessagePort.hpp>
#include <OBJCXX/Foundation/Classes/NSMessagePortNameServer.hpp>
#include <OBJCXX/Foundation/Classes/NSMetadataItem.hpp>
#include <OBJCXX/Foundation/Classes/NSMetadataQuery.hpp>
#include <OBJCXX/Foundation/Classes/NSMetadataQueryAttributeValueTuple.hpp>
#include <OBJCXX/Foundation/Classes/NSMetadataQueryResultGroup.hpp>
#include <OBJCXX/Foundation/Classes/NSMethodSignature.hpp>
#include <OBJCXX/Foundation/Classes/NSMiddleSpecifier.hpp>
#include <OBJCXX/Foundation/Classes/NSMoveCommand.hpp>
#include <OBJCXX/Foundation/Classes/NSMutableArray.hpp>
#include <OBJCXX/Foundation/Classes/NSMutableAttributedString.hpp>
#include <OBJCXX/Foundation/Classes/NSMutableCharacterSet.hpp>
#include <OBJCXX/Foundation/Classes/NSMutableData.hpp>
#include <OBJCXX/Foundation/Classes/NSMutableDictionary.hpp>
#include <OBJCXX/Foundation/Classes/NSMutableIndexSet.hpp>
#include <OBJCXX/Foundation/Classes/NSMutableOrderedSet.hpp>
#include <OBJCXX/Foundation/Classes/NSMutableSet.hpp>
#include <OBJCXX/Foundation/Classes/NSMutableString.hpp>
#include <OBJCXX/Foundation/Classes/NSMutableURLRequest.hpp>
#include <OBJCXX/Foundation/Classes/NSNameSpecifier.hpp>
#include <OBJCXX/Foundation/Classes/NSNetService.hpp>
#include <OBJCXX/Foundation/Classes/NSNetServiceBrowser.hpp>
#include <OBJCXX/Foundation/Classes/NSNotification.hpp>
#include <OBJCXX/Foundation/Classes/NSNotificationCenter.hpp>
#include <OBJCXX/Foundation/Classes/NSNotificationQueue.hpp>
#include <OBJCXX/Foundation/Classes/NSNull.hpp>
#include <OBJCXX/Foundation/Classes/NSNumber.hpp>
#include <OBJCXX/Foundation/Classes/NSNumberFormatter.hpp>
#include <OBJCXX/Foundation/Classes/NSObject.hpp>
#include <OBJCXX/Foundation/Classes/NSOperation.hpp>
#include <OBJCXX/Foundation/Classes/NSOperationQueue.hpp>
#include <OBJCXX/Foundation/Classes/NSOrderedSet.hpp>
#include <OBJCXX/Foundation/Classes/NSOrthography.hpp>
#include <OBJCXX/Foundation/Classes/NSOutputStream.hpp>
#include <OBJCXX/Foundation/Classes/NSPersonNameComponents.hpp>
#include <OBJCXX/Foundation/Classes/NSPersonNameComponentsFormatter.hpp>
#include <OBJCXX/Foundation/Classes/NSPipe.hpp>
#include <OBJCXX/Foundation/Classes/NSPointerArray.hpp>
#include <OBJCXX/Foundation/Classes/NSPointerFunctions.hpp>
#include <OBJCXX/Foundation/Classes/NSPort.hpp>
#include <OBJCXX/Foundation/Classes/NSPortCoder.hpp>
#include <OBJCXX/Foundation/Classes/NSPortMessage.hpp>
#include <OBJCXX/Foundation/Classes/NSPortNameServer.hpp>
#include <OBJCXX/Foundation/Classes/NSPositionalSpecifier.hpp>
#include <OBJCXX/Foundation/Classes/NSPredicate.hpp>
#include <OBJCXX/Foundation/Classes/NSProcessInfo.hpp>
#include <OBJCXX/Foundation/Classes/NSProgress.hpp>
#include <OBJCXX/Foundation/Classes/NSPropertyListSerialization.hpp>
#include <OBJCXX/Foundation/Classes/NSPropertySpecifier.hpp>
#include <OBJCXX/Foundation/Classes/NSProtocolChecker.hpp>
#include <OBJCXX/Foundation/Classes/NSProxy.hpp>
#include <OBJCXX/Foundation/Classes/NSPurgeableData.hpp>
#include <OBJCXX/Foundation/Classes/NSQuitCommand.hpp>
#include <OBJCXX/Foundation/Classes/NSRandomSpecifier.hpp>
#include <OBJCXX/Foundation/Classes/NSRangeSpecifier.hpp>
#include <OBJCXX/Foundation/Classes/NSRecursiveLock.hpp>
#include <OBJCXX/Foundation/Classes/NSRegularExpression.hpp>
#include <OBJCXX/Foundation/Classes/NSRelativeSpecifier.hpp>
#include <OBJCXX/Foundation/Classes/NSRunLoop.hpp>
#include <OBJCXX/Foundation/Classes/NSScanner.hpp>
#include <OBJCXX/Foundation/Classes/NSScriptClassDescription.hpp>
#include <OBJCXX/Foundation/Classes/NSScriptCoercionHandler.hpp>
#include <OBJCXX/Foundation/Classes/NSScriptCommand.hpp>
#include <OBJCXX/Foundation/Classes/NSScriptCommandDescription.hpp>
#include <OBJCXX/Foundation/Classes/NSScriptExecutionContext.hpp>
#include <OBJCXX/Foundation/Classes/NSScriptObjectSpecifier.hpp>
#include <OBJCXX/Foundation/Classes/NSScriptSuiteRegistry.hpp>
#include <OBJCXX/Foundation/Classes/NSScriptWhoseTest.hpp>
#include <OBJCXX/Foundation/Classes/NSSet.hpp>
#include <OBJCXX/Foundation/Classes/NSSetCommand.hpp>
#include <OBJCXX/Foundation/Classes/NSSocketPort.hpp>
#include <OBJCXX/Foundation/Classes/NSSocketPortNameServer.hpp>
#include <OBJCXX/Foundation/Classes/NSSortDescriptor.hpp>
#include <OBJCXX/Foundation/Classes/NSSpecifierTest.hpp>
#include <OBJCXX/Foundation/Classes/NSSpellServer.hpp>
#include <OBJCXX/Foundation/Classes/NSStream.hpp>
#include <OBJCXX/Foundation/Classes/NSString.hpp>
#include <OBJCXX/Foundation/Classes/NSTask.hpp>
#include <OBJCXX/Foundation/Classes/NSTextCheckingResult.hpp>
#include <OBJCXX/Foundation/Classes/NSThread.hpp>
#include <OBJCXX/Foundation/Classes/NSTimer.hpp>
#include <OBJCXX/Foundation/Classes/NSTimeZone.hpp>
#include <OBJCXX/Foundation/Classes/NSUbiquitousKeyValueStore.hpp>
#include <OBJCXX/Foundation/Classes/NSUnarchiver.hpp>
#include <OBJCXX/Foundation/Classes/NSUndoManager.hpp>
#include <OBJCXX/Foundation/Classes/NSUniqueIDSpecifier.hpp>
#include <OBJCXX/Foundation/Classes/NSURL.hpp>
#include <OBJCXX/Foundation/Classes/NSURLAuthenticationChallenge.hpp>
#include <OBJCXX/Foundation/Classes/NSURLCache.hpp>
#include <OBJCXX/Foundation/Classes/NSURLComponents.hpp>
#include <OBJCXX/Foundation/Classes/NSURLConnection.hpp>
#include <OBJCXX/Foundation/Classes/NSURLCredential.hpp>
#include <OBJCXX/Foundation/Classes/NSURLCredentialStorage.hpp>
#include <OBJCXX/Foundation/Classes/NSURLDownload.hpp>
#include <OBJCXX/Foundation/Classes/NSURLHandle.hpp>
#include <OBJCXX/Foundation/Classes/NSURLProtectionSpace.hpp>
#include <OBJCXX/Foundation/Classes/NSURLProtocol.hpp>
#include <OBJCXX/Foundation/Classes/NSURLQueryItem.hpp>
#include <OBJCXX/Foundation/Classes/NSURLRequest.hpp>
#include <OBJCXX/Foundation/Classes/NSURLResponse.hpp>
#include <OBJCXX/Foundation/Classes/NSURLSession.hpp>
#include <OBJCXX/Foundation/Classes/NSURLSessionConfiguration.hpp>
#include <OBJCXX/Foundation/Classes/NSURLSessionDataTask.hpp>
#include <OBJCXX/Foundation/Classes/NSURLSessionDownloadTask.hpp>
#include <OBJCXX/Foundation/Classes/NSURLSessionStreamTask.hpp>
#include <OBJCXX/Foundation/Classes/NSURLSessionTask.hpp>
#include <OBJCXX/Foundation/Classes/NSURLSessionUploadTask.hpp>
#include <OBJCXX/Foundation/Classes/NSUserActivity.hpp>
#include <OBJCXX/Foundation/Classes/NSUserAppleScriptTask.hpp>
#include <OBJCXX/Foundation/Classes/NSUserAutomatorTask.hpp>
#include <OBJCXX/Foundation/Classes/NSUserDefaults.hpp>
#include <OBJCXX/Foundation/Classes/NSUserNotification.hpp>
#include <OBJCXX/Foundation/Classes/NSUserNotificationAction.hpp>
#include <OBJCXX/Foundation/Classes/NSUserNotificationCenter.hpp>
#include <OBJCXX/Foundation/Classes/NSUserScriptTask.hpp>
#include <OBJCXX/Foundation/Classes/NSUserUnixTask.hpp>
#include <OBJCXX/Foundation/Classes/NSUUID.hpp>
#include <OBJCXX/Foundation/Classes/NSValue.hpp>
#include <OBJCXX/Foundation/Classes/NSValueTransformer.hpp>
#include <OBJCXX/Foundation/Classes/NSWhoseSpecifier.hpp>
#include <OBJCXX/Foundation/Classes/NSXMLDocument.hpp>
#include <OBJCXX/Foundation/Classes/NSXMLDTD.hpp>
#include <OBJCXX/Foundation/Classes/NSXMLDTDNode.hpp>
#include <OBJCXX/Foundation/Classes/NSXMLElement.hpp>
#include <OBJCXX/Foundation/Classes/NSXMLNode.hpp>
#include <OBJCXX/Foundation/Classes/NSXMLParser.hpp>
#include <OBJCXX/Foundation/Classes/NSXPCConnection.hpp>
#include <OBJCXX/Foundation/Classes/NSXPCInterface.hpp>
#include <OBJCXX/Foundation/Classes/NSXPCListener.hpp>
#include <OBJCXX/Foundation/Classes/NSXPCListenerEndpoint.hpp>

#endif /* OBJCXX_H */
