//
//  NSNumber+YASAudioTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//
//

#import <XCTest/XCTest.h>
#import "NSNumber+YASAudio.h"

@interface NSNumber_YASAudioTests : XCTestCase

@end

@implementation NSNumber_YASAudioTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testGetValue
{
    XCTAssertEqual([@0 uint32Value], 0);
    XCTAssertEqual([@1 uint32Value], 1);
    XCTAssertEqual([@(UINT32_MAX) uint32Value], UINT32_MAX);
    XCTAssertNotEqual([@((UInt64)UINT32_MAX + 1) uint32Value], (UInt64)UINT32_MAX + 1);
    XCTAssertNotEqual([@((SInt64)-1) uint32Value], (SInt64)-1);
}

@end
