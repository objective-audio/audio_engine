//
//  yas_result_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "yas_result.h"

@interface yas_result_tests : XCTestCase

@end

@implementation yas_result_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testCreateSuccessResult
{
    yas::result<bool, int> result(true);

    XCTAssertTrue(result.is_success());
    XCTAssertTrue(result.value());
    XCTAssertEqual(result.value(), true);
}

- (void)testCreateVoidPointerSuccessResult
{
    yas::result<std::nullptr_t, int> result(nullptr);

    XCTAssertTrue(result);
    XCTAssertTrue(result.is_success());
    XCTAssertEqual(result.value(), nullptr);
}

- (void)testCreateErrorResult
{
    yas::result<bool, int> result(10);

    XCTAssertFalse(result);
    XCTAssertFalse(result.is_success());
    XCTAssertEqual(result.error(), 10);
}

- (void)testReceiveSuccessResult
{
    bool value = true;
    bool result_flag;

    if (auto result = yas::result<bool, int>(std::move(value))) {
        result_flag = true;
    } else {
        result_flag = false;
    }

    XCTAssertTrue(result_flag);
}

- (void)testReceiveErrorResult
{
    int value = 10;
    bool result_flag;

    if (auto result = yas::result<bool, int>(std::move(value))) {
        result_flag = true;
    } else {
        result_flag = false;
    }

    XCTAssertFalse(result_flag);
}

@end
