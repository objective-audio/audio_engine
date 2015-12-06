//
//  yas_result_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

@interface yas_result_tests : XCTestCase

@end

@implementation yas_result_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create_success_result_move_constructor {
    std::string value("test_value");
    yas::result<std::string, int> result(std::move(value));

    XCTAssertTrue(result);
    XCTAssertTrue(result.is_success());
    XCTAssertEqual(result.value(), std::string("test_value"));

    XCTAssertNotEqual(value, result.value());
}

- (void)test_create_success_result_copy_constructor {
    std::string value("test_value");
    yas::result<std::string, int> result(value);

    XCTAssertTrue(result);
    XCTAssertTrue(result.is_success());
    XCTAssertEqual(result.value(), std::string("test_value"));

    XCTAssertEqual(value, result.value());
}

- (void)test_create_void_ptr_sucess_result {
    yas::result<std::nullptr_t, int> result(nullptr);

    XCTAssertTrue(result);
    XCTAssertTrue(result.is_success());
    XCTAssertEqual(result.value(), nullptr);
}

- (void)test_create_error_result_move_constructor {
    std::string error("test_error");
    yas::result<bool, std::string> result(std::move(error));

    XCTAssertFalse(result);
    XCTAssertFalse(result.is_success());
    XCTAssertEqual(result.error(), std::string("test_error"));

    XCTAssertNotEqual(error, result.error());
}

- (void)test_create_error_result_copy_constructor {
    std::string error("test_error");
    yas::result<bool, std::string> result(error);

    XCTAssertFalse(result);
    XCTAssertFalse(result.is_success());
    XCTAssertEqual(result.error(), std::string("test_error"));

    XCTAssertEqual(error, result.error());
}

- (void)test_receive_success_result {
    bool value = true;
    bool result_flag;

    if (auto result = yas::result<bool, int>(std::move(value))) {
        result_flag = true;
    } else {
        result_flag = false;
    }

    XCTAssertTrue(result_flag);
}

- (void)test_receive_error_result {
    int error = 10;
    bool result_flag;

    if (auto result = yas::result<bool, int>(std::move(error))) {
        result_flag = true;
    } else {
        result_flag = false;
    }

    XCTAssertFalse(result_flag);
}

- (void)test_value_opt {
    bool value = true;

    auto result = yas::result<bool, int>(std::move(value));
    auto value_opt = result.value_opt();

    XCTAssertTrue(value_opt);
    XCTAssertEqual(*value_opt, true);

    auto error_opt = result.error_opt();
    XCTAssertFalse(error_opt);
}

- (void)test_error_opt {
    int error = 20;

    auto result = yas::result<bool, int>(std::move(error));
    auto error_opt = result.error_opt();

    XCTAssertTrue(error_opt);
    XCTAssertEqual(*error_opt, 20);

    auto value_opt = result.value_opt();

    XCTAssertFalse(value_opt);
}

@end
