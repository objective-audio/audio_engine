//
//  time_tests.mm
//

#import <XCTest/XCTest.h>
#include <audio-processing/time/time.h>
#include <sstream>

using namespace yas;
using namespace yas::proc;

@interface time_tests : XCTestCase

@end

@implementation time_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create_range_time {
    proc::time time{1, 2};

    XCTAssertTrue(time);
    XCTAssertTrue(time.type() == typeid(time::range));
}

- (void)test_create_range_time_from_range {
    proc::time time{time::range{0, 1}};

    XCTAssertTrue(time);
    XCTAssertTrue(time.type() == typeid(time::range));
}

- (void)test_create_frame_time {
    proc::time time{3};

    XCTAssertTrue(time);
    XCTAssertTrue(time.type() == typeid(time::frame));

    auto const &frame = time.get<time::frame>();

    XCTAssertEqual(frame, 3);
}

- (void)test_create_any_time {
    proc::time time;

    XCTAssertTrue(time);
    XCTAssertTrue(time.type() == typeid(time::any));
}

- (void)test_make_range_time {
    auto time = make_range_time(1, 2);

    XCTAssertTrue(time);
    XCTAssertTrue(time.type() == typeid(time::range));
}

- (void)test_make_time_frame {
    auto time = make_frame_time(3);

    XCTAssertTrue(time);
    XCTAssertTrue(time.type() == typeid(time::frame));
}

- (void)test_make_time_any {
    auto time = make_any_time();

    XCTAssertTrue(time);
    XCTAssertTrue(time.type() == typeid(time::any));
}

- (void)test_assign_range {
    auto time = make_any_time();

    time = time::range{0, 1};

    XCTAssertTrue(time.type() == typeid(time::range));
}

- (void)test_get_range_time {
    proc::time time{1, 2};

    auto const &range = time.get<time::range>();

    XCTAssertEqual(range.frame, 1);
    XCTAssertEqual(range.length, 2);
}

- (void)test_get_frame_time {
    proc::time time{3};

    auto const &frame = time.get<time::frame>();

    XCTAssertEqual(frame, 3);
}

- (void)test_is_equal_range_time {
    auto time1a = make_range_time(0, 1);
    auto time1b = make_range_time(0, 1);
    auto time2 = make_range_time(0, 2);
    auto time3 = make_range_time(1, 1);

    XCTAssertTrue(time1a == time1a);
    XCTAssertTrue(time1a == time1b);
    XCTAssertFalse(time1a == time2);
    XCTAssertFalse(time1a == time3);

    XCTAssertFalse(time1a != time1a);
    XCTAssertFalse(time1a != time1b);
    XCTAssertTrue(time1a != time2);
    XCTAssertTrue(time1a != time3);
}

- (void)test_is_equal_frame_time {
    auto time1a = make_frame_time(1);
    auto time1b = make_frame_time(1);
    auto time2 = make_frame_time(2);

    XCTAssertTrue(time1a == time1a);
    XCTAssertTrue(time1a == time1b);
    XCTAssertFalse(time1a == time2);

    XCTAssertFalse(time1a != time1a);
    XCTAssertFalse(time1a != time1b);
    XCTAssertTrue(time1a != time2);
}

- (void)test_is_equal_any_time {
    auto time1a = make_any_time();
    auto time1b = make_any_time();

    XCTAssertTrue(time1a == time1a);
    XCTAssertTrue(time1a == time1b);

    XCTAssertFalse(time1a != time1a);
    XCTAssertFalse(time1a != time1b);
}

- (void)test_is_range_type {
    auto range_time = make_range_time(1, 2);
    auto frame_time = make_frame_time(3);
    auto any_time = make_any_time();

    XCTAssertTrue(range_time.is_range_type());
    XCTAssertFalse(frame_time.is_range_type());
    XCTAssertFalse(any_time.is_range_type());
}

- (void)test_is_frame_type {
    auto range_time = make_range_time(1, 2);
    auto frame_time = make_frame_time(3);
    auto any_time = make_any_time();

    XCTAssertFalse(range_time.is_frame_type());
    XCTAssertTrue(frame_time.is_frame_type());
    XCTAssertFalse(any_time.is_frame_type());
}

- (void)test_is_any_type {
    auto range_time = make_range_time(1, 2);
    auto frame_time = make_frame_time(3);
    auto any_time = make_any_time();

    XCTAssertFalse(range_time.is_any_type());
    XCTAssertFalse(frame_time.is_any_type());
    XCTAssertTrue(any_time.is_any_type());
}

- (void)test_less_than_same_type {
    XCTAssertFalse(make_range_time(0, 1) < make_range_time(0, 1));
    XCTAssertTrue(make_range_time(0, 1) < make_range_time(0, 2));
    XCTAssertFalse(make_range_time(1, 1) < make_range_time(0, 1));

    XCTAssertFalse(make_frame_time(1) < make_frame_time(0));
    XCTAssertFalse(make_frame_time(1) < make_frame_time(1));
    XCTAssertTrue(make_frame_time(1) < make_frame_time(2));

    XCTAssertFalse(make_any_time() < make_any_time());
}

- (void)test_less_than_different_type {
    XCTAssertTrue(make_frame_time(1) < make_range_time(0, 1));
    XCTAssertTrue(make_frame_time(1) < make_range_time(1, 1));

    XCTAssertFalse(make_range_time(0, 1) < make_frame_time(1));
    XCTAssertFalse(make_range_time(1, 1) < make_range_time(1, 1));

    XCTAssertFalse(make_frame_time(0) < make_any_time());
    XCTAssertTrue(make_any_time() < make_frame_time(0));

    XCTAssertFalse(make_range_time(0, 1) < make_any_time());
    XCTAssertTrue(make_any_time() < make_range_time(0, 1));
}

- (void)test_is_contain {
    auto range1 = make_range_time(0, 1);
    auto range2 = make_range_time(0, 2);
    auto range2b = make_range_time(0, 2);
    auto range3 = make_range_time(0, 3);

    auto frame0 = make_frame_time(0);
    auto frame2 = make_frame_time(2);

    auto any = make_any_time();

    XCTAssertTrue(range2.is_contain(range1));
    XCTAssertTrue(range2.is_contain(range2));
    XCTAssertTrue(range2.is_contain(range2b));
    XCTAssertFalse(range2.is_contain(range3));
    XCTAssertTrue(range2.is_contain(frame0));
    XCTAssertFalse(range2.is_contain(frame2));
    XCTAssertTrue(range2.is_contain(any));

    XCTAssertFalse(frame0.is_contain(range1));
    XCTAssertFalse(frame0.is_contain(frame0));
    XCTAssertFalse(frame0.is_contain(any));

    XCTAssertFalse(any.is_contain(range1));
    XCTAssertFalse(any.is_contain(frame0));
    XCTAssertFalse(any.is_contain(any));
}

- (void)test_crop {
    auto range = time::range{0, 3};

    auto cropped_ranges = range.cropped({0, 1});
    XCTAssertEqual(cropped_ranges.size(), 1);
    XCTAssertTrue((cropped_ranges[0] == time::range{1, 2}));

    cropped_ranges = range.cropped({1, 1});
    XCTAssertEqual(cropped_ranges.size(), 2);
    XCTAssertTrue((cropped_ranges[0] == time::range{0, 1}));
    XCTAssertTrue((cropped_ranges[1] == time::range{2, 1}));

    cropped_ranges = range.cropped({2, 1});
    XCTAssertEqual(cropped_ranges.size(), 1);
    XCTAssertTrue((cropped_ranges[0] == time::range{0, 2}));

    cropped_ranges = range.cropped({2, 1});
    XCTAssertEqual(cropped_ranges.size(), 1);
    XCTAssertTrue((cropped_ranges[0] == time::range{0, 2}));

    cropped_ranges = range.cropped({0, 2});
    XCTAssertEqual(cropped_ranges.size(), 1);
    XCTAssertTrue((cropped_ranges[0] == time::range{2, 1}));

    cropped_ranges = range.cropped({1, 2});
    XCTAssertEqual(cropped_ranges.size(), 1);
    XCTAssertTrue((cropped_ranges[0] == time::range{0, 1}));

    cropped_ranges = range.cropped({0, 3});
    XCTAssertEqual(cropped_ranges.size(), 0);

    cropped_ranges = range.cropped({-1, 3});
    XCTAssertEqual(cropped_ranges.size(), 1);
    XCTAssertTrue((cropped_ranges[0] == time::range{2, 1}));

    cropped_ranges = range.cropped({1, 3});
    XCTAssertEqual(cropped_ranges.size(), 1);
    XCTAssertTrue((cropped_ranges[0] == time::range{0, 1}));

    cropped_ranges = range.cropped({10, 3});
    XCTAssertEqual(cropped_ranges.size(), 1);
    XCTAssertTrue((cropped_ranges[0] == time::range{0, 3}));
}

- (void)test_range_offset {
    XCTAssertEqual(time::range(0, 1).offset(1), time::range(1, 1));
    XCTAssertEqual(time::range(0, 1).offset(-1), time::range(-1, 1));
}

- (void)test_any_time_offset {
    auto const any_time = make_any_time();

    XCTAssertEqual(any_time.offset(0), any_time);
    XCTAssertEqual(any_time.offset(1), any_time);
    XCTAssertEqual(any_time.offset(-1), any_time);
}

- (void)test_frame_time_offset {
    auto const frame_time = make_frame_time(0);

    XCTAssertEqual(frame_time.offset(0), make_frame_time(0));
    XCTAssertEqual(frame_time.offset(1), make_frame_time(1));
    XCTAssertEqual(frame_time.offset(-1), make_frame_time(-1));
}

- (void)test_range_time_offset {
    auto const range_time = make_range_time(0, 1);

    XCTAssertEqual(range_time.offset(0), make_range_time(0, 1));
    XCTAssertEqual(range_time.offset(1), make_range_time(1, 1));
    XCTAssertEqual(range_time.offset(-1), make_range_time(-1, 1));
}

- (void)test_time_to_string {
    XCTAssertEqual(to_string(make_frame_time(3)), "3");
    XCTAssertEqual(to_string(make_range_time(4, 5)), "{4, 5}");
    XCTAssertEqual(to_string(make_any_time()), "any");
}

- (void)test_time_range_to_string {
    XCTAssertEqual(to_string(time::range{1, 2}), "{1, 2}");
}

- (void)test_time_ostream {
    auto const values = {make_frame_time(3), make_range_time(4, 5), make_any_time()};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

- (void)test_time_range_ostream {
    auto const values = {time::range{1, 2}};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

@end
