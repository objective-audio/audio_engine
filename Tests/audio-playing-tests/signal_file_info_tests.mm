//
//  signal_file_info_tests.mm
//

#import <XCTest/XCTest.h>
#import <cpp-utils/boolean.h>
#import <audio-playing/umbrella.hpp>

using namespace yas;
using namespace yas::playing;

@interface signal_file_info_tests : XCTestCase

@end

@implementation signal_file_info_tests

- (void)setUp {
}

- (void)tearDown {
}

- (void)test_file_name {
    XCTAssertEqual(signal_file_info("", {10, 20}, typeid(int64_t)).file_name(), "signal_10_20_i64");
    XCTAssertEqual(signal_file_info("", {0, 1}, typeid(double)).file_name(), "signal_0_1_f64");
    XCTAssertEqual(signal_file_info("", {-1, 2}, typeid(boolean)).file_name(), "signal_-1_2_b");
}

- (void)test_to_signal_file_info {
    auto info = to_signal_file_info("path/to/signal_10_20_i64");

    XCTAssertTrue(info);
    XCTAssertEqual(info->path, "path/to/signal_10_20_i64");
    XCTAssertEqual(info->range, (proc::time::range{10, 20}));
    XCTAssertTrue(info->sample_type == typeid(int64_t));
}

- (void)test_to_signal_file_info_failed {
    auto info = to_signal_file_info("");

    XCTAssertFalse(info);
}

- (void)test_to_sample_type_name {
    XCTAssertEqual(to_sample_type_name(typeid(double)), "f64");
    XCTAssertEqual(to_sample_type_name(typeid(float)), "f32");
    XCTAssertEqual(to_sample_type_name(typeid(int64_t)), "i64");
    XCTAssertEqual(to_sample_type_name(typeid(uint64_t)), "u64");
    XCTAssertEqual(to_sample_type_name(typeid(int32_t)), "i32");
    XCTAssertEqual(to_sample_type_name(typeid(uint32_t)), "u32");
    XCTAssertEqual(to_sample_type_name(typeid(int16_t)), "i16");
    XCTAssertEqual(to_sample_type_name(typeid(uint16_t)), "u16");
    XCTAssertEqual(to_sample_type_name(typeid(int8_t)), "i8");
    XCTAssertEqual(to_sample_type_name(typeid(uint8_t)), "u8");
    XCTAssertEqual(to_sample_type_name(typeid(boolean)), "b");

    XCTAssertEqual(to_sample_type_name(typeid(std::string)), "");
}

- (void)test_to_sample_type {
    XCTAssertTrue(to_sample_type("f64") == typeid(double));
    XCTAssertTrue(to_sample_type("f32") == typeid(float));
    XCTAssertTrue(to_sample_type("i64") == typeid(int64_t));
    XCTAssertTrue(to_sample_type("u64") == typeid(uint64_t));
    XCTAssertTrue(to_sample_type("i32") == typeid(int32_t));
    XCTAssertTrue(to_sample_type("u32") == typeid(uint32_t));
    XCTAssertTrue(to_sample_type("i16") == typeid(int16_t));
    XCTAssertTrue(to_sample_type("u16") == typeid(uint16_t));
    XCTAssertTrue(to_sample_type("i8") == typeid(int8_t));
    XCTAssertTrue(to_sample_type("u8") == typeid(uint8_t));
    XCTAssertTrue(to_sample_type("b") == typeid(boolean));

    XCTAssertTrue(to_sample_type("") == typeid(std::nullptr_t));
}

@end
