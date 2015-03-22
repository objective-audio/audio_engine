//
//  NSException+YASAudioTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "NSException+YASAudio.h"
#import "NSError+YASAudio.h"

@interface NSException_YASAudioTests : XCTestCase

@end

@implementation NSException_YASAudioTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testRaiseWithReason
{
    XCTAssertThrowsSpecificNamed([NSException yas_raiseWithReason:@"reason"], NSException, YASAudioGenericException);
}

- (void)testRaiseWithError
{
    NSError *error = nil;
    XCTAssertNoThrow([NSException yas_raiseIfError:error]);

    error = [NSError yas_errorWithCode:1];

    XCTAssertNotNil(error);
    XCTAssertThrowsSpecificNamed([NSException yas_raiseIfError:error], NSException, YASAudioNSErrorException);
}

- (void)testRaiseIfAudioUnitError
{
    XCTAssertNoThrow([NSException yas_raiseIfAudioUnitError:noErr]);
    XCTAssertThrowsSpecificNamed([NSException yas_raiseIfAudioUnitError:1], NSException,
                                 YASAudioAudioUnitErrorException);
}

- (void)testRaiseThread
{
    XCTAssertThrowsSpecificNamed([NSException yas_raiseIfMainThread], NSException, YASAudioGenericException);
    XCTAssertNoThrow([NSException yas_raiseIfSubThread]);

    XCTestExpectation *expectation = [self expectationWithDescription:nil];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NSException yas_raiseIfMainThread];
        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1.0 handler:NULL];
}

@end
