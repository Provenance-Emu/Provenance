//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2017 hamcrest.org. See LICENSE.txt

#import <OCHamcrestTVOS/HCAllOf.h>
#import <OCHamcrestTVOS/HCAnyOf.h>
#import <OCHamcrestTVOS/HCArgumentCaptor.h>
#import <OCHamcrestTVOS/HCAssertThat.h>
#import <OCHamcrestTVOS/HCConformsToProtocol.h>
#import <OCHamcrestTVOS/HCDescribedAs.h>
#import <OCHamcrestTVOS/HCEvery.h>
#import <OCHamcrestTVOS/HCHasCount.h>
#import <OCHamcrestTVOS/HCHasDescription.h>
#import <OCHamcrestTVOS/HCHasProperty.h>
#import <OCHamcrestTVOS/HCIs.h>
#import <OCHamcrestTVOS/HCIsAnything.h>
#import <OCHamcrestTVOS/HCIsCloseTo.h>
#import <OCHamcrestTVOS/HCIsCollectionContaining.h>
#import <OCHamcrestTVOS/HCIsCollectionContainingInAnyOrder.h>
#import <OCHamcrestTVOS/HCIsCollectionContainingInOrder.h>
#import <OCHamcrestTVOS/HCIsCollectionContainingInRelativeOrder.h>
#import <OCHamcrestTVOS/HCIsCollectionOnlyContaining.h>
#import <OCHamcrestTVOS/HCIsDictionaryContaining.h>
#import <OCHamcrestTVOS/HCIsDictionaryContainingEntries.h>
#import <OCHamcrestTVOS/HCIsDictionaryContainingKey.h>
#import <OCHamcrestTVOS/HCIsDictionaryContainingValue.h>
#import <OCHamcrestTVOS/HCIsEmptyCollection.h>
#import <OCHamcrestTVOS/HCIsEqual.h>
#import <OCHamcrestTVOS/HCIsEqualIgnoringCase.h>
#import <OCHamcrestTVOS/HCIsEqualCompressingWhiteSpace.h>
#import <OCHamcrestTVOS/HCIsEqualToNumber.h>
#import <OCHamcrestTVOS/HCIsIn.h>
#import <OCHamcrestTVOS/HCIsInstanceOf.h>
#import <OCHamcrestTVOS/HCIsNil.h>
#import <OCHamcrestTVOS/HCIsNot.h>
#import <OCHamcrestTVOS/HCIsSame.h>
#import <OCHamcrestTVOS/HCIsTrueFalse.h>
#import <OCHamcrestTVOS/HCIsTypeOf.h>
#import <OCHamcrestTVOS/HCNumberAssert.h>
#import <OCHamcrestTVOS/HCOrderingComparison.h>
#import <OCHamcrestTVOS/HCStringContains.h>
#import <OCHamcrestTVOS/HCStringContainsInOrder.h>
#import <OCHamcrestTVOS/HCStringEndsWith.h>
#import <OCHamcrestTVOS/HCStringStartsWith.h>
#import <OCHamcrestTVOS/HCTestFailure.h>
#import <OCHamcrestTVOS/HCTestFailureReporter.h>
#import <OCHamcrestTVOS/HCTestFailureReporterChain.h>
#import <OCHamcrestTVOS/HCThrowsException.h>

// Carthage workaround: Include transitive public headers
#import <OCHamcrestTVOS/HCBaseDescription.h>
#import <OCHamcrestTVOS/HCCollect.h>
#import <OCHamcrestTVOS/HCRequireNonNilObject.h>
#import <OCHamcrestTVOS/HCStringDescription.h>
#import <OCHamcrestTVOS/HCWrapInMatcher.h>
