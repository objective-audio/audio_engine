//
//  NSError+YASAudioTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "NSError+YASAudio.h"
#import <AudioToolbox/AudioToolbox.h>

@interface NSError_YASAudioTests : XCTestCase

@end

@implementation NSError_YASAudioTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testGetError
{
    NSError *error = nil;
    [NSError yas_error:&error code:1];

    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, YASAudioErrorDomain);
    XCTAssertEqual(error.code, 1);
}

- (void)testGetErrorWithAudioErrorCode
{
    NSError *error = nil;
    [NSError yas_error:&error code:1 audioErrorCode:kAudioUnitErr_InvalidProperty];

    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, YASAudioErrorDomain);
    XCTAssertEqual(error.code, 1);
    XCTAssertEqualObjects(error.userInfo[YASAudioErrorCodeNumberKey], @(kAudioUnitErr_InvalidProperty));
    XCTAssertEqualObjects(error.userInfo[YASAudioErrorCodeDescriptionKey], @"AudioUnit Error - Invalid Property");

    error = nil;

    const OSStatus audioUnitErrors[] = {
        kAudioUnitErr_InvalidProperty, kAudioUnitErr_InvalidParameter, kAudioUnitErr_InvalidElement,
        kAudioUnitErr_NoConnection, kAudioUnitErr_FailedInitialization, kAudioUnitErr_TooManyFramesToProcess,
        kAudioUnitErr_InvalidFile, kAudioUnitErr_FormatNotSupported, kAudioUnitErr_Uninitialized,
        kAudioUnitErr_InvalidScope, kAudioUnitErr_PropertyNotWritable, kAudioUnitErr_CannotDoInCurrentContext,
        kAudioUnitErr_InvalidPropertyValue, kAudioUnitErr_PropertyNotInUse, kAudioUnitErr_Initialized,
        kAudioUnitErr_InvalidOfflineRender, kAudioUnitErr_Unauthorized,
    };

    const UInt32 errorCount = sizeof(audioUnitErrors) / sizeof(OSStatus);

    for (UInt32 i = 0; i < errorCount; i++) {
        [NSError yas_error:&error code:1 audioErrorCode:audioUnitErrors[i]];
        NSString *description = error.userInfo[YASAudioErrorCodeDescriptionKey];
        XCTAssertTrue([description hasPrefix:@"AudioUnit Error - "]);

        error = nil;
    }

    [NSError yas_error:&error code:1 audioErrorCode:noErr];
    NSString *description = error.userInfo[YASAudioErrorCodeDescriptionKey];
    XCTAssertEqual(description.length, 0);
}

@end
