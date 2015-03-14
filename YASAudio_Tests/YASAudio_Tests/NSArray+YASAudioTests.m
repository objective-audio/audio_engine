//
//  NSArray+YASAudioTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "NSArray+YASAudio.h"

@interface NSArray_YASAudioTests : XCTestCase

@end

@implementation NSArray_YASAudioTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testEmptyNumberInLength
{
    NSArray *array = @[ @1 ];

    XCTAssertEqualObjects([array yas_emptyNumberInLength:2], @0);

    array = @[ @0 ];

    XCTAssertEqualObjects([array yas_emptyNumberInLength:2], @1);
    XCTAssertNil([array yas_emptyNumberInLength:1]);
}

- (void)testArrayOfProperty
{
    NSArray *array = @[ @0, @1 ];
    NSArray *stringValueArray = [array yas_arrayOfPropertyForKey:@"stringValue"];

    XCTAssertEqualObjects(stringValueArray[0], @"0");
    XCTAssertEqualObjects(stringValueArray[1], @"1");

    XCTAssertThrows([array yas_arrayOfPropertyForKey:nil]);
}

- (void)testArrayWithBlock
{
    const NSUInteger count = 5;

    NSArray *array = [NSArray yas_arrayWithBlock:^id(NSUInteger idx, BOOL *stop) {
      return @(idx);
    } count:count];

    XCTAssertEqual(array.count, count);
    for (NSUInteger i = 0; i < count; i++) {
        XCTAssertEqualObjects(array[i], @(i));
    }

    const NSUInteger stopCount = 3;

    NSArray *stopArray = [NSArray yas_arrayWithBlock:^id(NSUInteger idx, BOOL *stop) {
      if (idx == stopCount - 1) {
          *stop = YES;
      }
      return @(idx);
    } count:count];

    XCTAssertEqual(stopArray.count, stopCount);
    for (NSUInteger i = 0; i < stopCount; i++) {
        XCTAssertEqualObjects(array[i], @(i));
    }

    XCTAssertNil([NSArray yas_arrayWithBlock:nil count:count]);
}

@end
