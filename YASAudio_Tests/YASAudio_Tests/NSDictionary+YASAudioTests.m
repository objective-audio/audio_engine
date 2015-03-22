//
//  NSDictionary+YASAudioTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "NSDictionary+YASAudio.h"

@interface NSDictionary_YASAudioTests : XCTestCase

@end

@implementation NSDictionary_YASAudioTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testEmptyNumberKeyInLength
{
    NSDictionary *dictionary = @{ @1: @"1" };

    XCTAssertEqualObjects([dictionary yas_emptyNumberKeyInLength:2], @0);

    dictionary = @{ @0: @"0" };

    XCTAssertEqualObjects([dictionary yas_emptyNumberKeyInLength:2], @1);

    dictionary = @{ @0: @"0" };

    XCTAssertNil([dictionary yas_emptyNumberKeyInLength:1]);
}

@end
