//
//  compare_signal_modules_tests.mm
//

#import <XCTest/XCTest.h>
#import <cpp-utils/boolean.h>
#import "utils/test_utils.h"

@interface compare_signal_modules_tests : XCTestCase

@end

@implementation compare_signal_modules_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_make_signal_modules {
    XCTAssertTrue(make_signal_module<int16_t>(compare::kind::is_equal));
    XCTAssertTrue(make_signal_module<int16_t>(compare::kind::is_not_equal));
    XCTAssertTrue(make_signal_module<int16_t>(compare::kind::is_greater));
    XCTAssertTrue(make_signal_module<int16_t>(compare::kind::is_greater_equal));
    XCTAssertTrue(make_signal_module<int16_t>(compare::kind::is_less));
    XCTAssertTrue(make_signal_module<int16_t>(compare::kind::is_less_equal));
}

- (void)test_is_equal {
    length_t const process_length = 6;

    int16_t const left_data[3] = {
        1,
        2,
        3,
    };

    int16_t const right_data[3] = {
        2,
        2,
        2,
    };

    auto stream = test::make_signal_stream(time::range{0, process_length}, left_data, time::range{1, 3}, 0, right_data,
                                           time::range{2, 3}, 1);

    auto module = make_signal_module<int16_t>(compare::kind::is_equal);
    connect(module, compare::input::left, 0);
    connect(module, compare::input::right, 1);
    connect(module, compare::output::result, 2);

    module->process({0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const &events = stream.channel(2).events();

    XCTAssertEqual(events.size(), 1);

    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<boolean>();

    XCTAssertEqual(vec.size(), process_length);
    XCTAssertTrue(vec[0]);   // 0 == 0
    XCTAssertFalse(vec[1]);  // 1 == 0
    XCTAssertTrue(vec[2]);   // 2 == 2
    XCTAssertFalse(vec[3]);  // 3 == 2
    XCTAssertFalse(vec[4]);  // 0 == 2
    XCTAssertTrue(vec[5]);   // 0 == 0
}

- (void)test_is_not_equal {
    length_t const process_length = 6;

    int16_t const left_data[3] = {
        1,
        2,
        3,
    };

    int16_t const right_data[3] = {
        2,
        2,
        2,
    };

    auto stream = test::make_signal_stream(time::range{0, process_length}, left_data, time::range{1, 3}, 0, right_data,
                                           time::range{2, 3}, 1);

    auto module = make_signal_module<int16_t>(compare::kind::is_not_equal);
    connect(module, compare::input::left, 0);
    connect(module, compare::input::right, 1);
    connect(module, compare::output::result, 2);

    module->process({0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const &events = stream.channel(2).events();

    XCTAssertEqual(events.size(), 1);

    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<boolean>();

    XCTAssertEqual(vec.size(), process_length);
    XCTAssertFalse(vec[0]);  // 0 != 0
    XCTAssertTrue(vec[1]);   // 1 != 0
    XCTAssertFalse(vec[2]);  // 2 != 2
    XCTAssertTrue(vec[3]);   // 3 != 2
    XCTAssertTrue(vec[4]);   // 0 != 2
    XCTAssertFalse(vec[5]);  // 0 != 0
}

- (void)test_is_greater {
    length_t const process_length = 11;

    int16_t const left_data[6] = {
        -1, 0, 1, 2, 3, 4,
    };

    int16_t const right_data[6] = {
        3, 3, 3, 1, 0, -1,
    };

    auto stream = test::make_signal_stream(time::range{0, process_length}, left_data, time::range{1, 6}, 0, right_data,
                                           time::range{4, 6}, 1);

    auto module = make_signal_module<int16_t>(compare::kind::is_greater);
    connect(module, compare::input::left, 0);
    connect(module, compare::input::right, 1);
    connect(module, compare::output::result, 2);

    module->process({0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const &events = stream.channel(2).events();

    XCTAssertEqual(events.size(), 1);

    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<boolean>();

    XCTAssertEqual(vec.size(), process_length);
    XCTAssertFalse(vec[0]);   // 0 > 0
    XCTAssertFalse(vec[1]);   // -1 > 0
    XCTAssertFalse(vec[2]);   // 0 > 0
    XCTAssertTrue(vec[3]);    // 1 > 0
    XCTAssertFalse(vec[4]);   // 2 > 3
    XCTAssertFalse(vec[5]);   // 3 > 3
    XCTAssertTrue(vec[6]);    // 4 > 3
    XCTAssertFalse(vec[7]);   // 0 > 1
    XCTAssertFalse(vec[8]);   // 0 > 0
    XCTAssertTrue(vec[9]);    // 0 > -1
    XCTAssertFalse(vec[10]);  // 0 > 0
}

- (void)test_is_greater_equal {
    length_t const process_length = 11;

    int16_t const left_data[6] = {
        -1, 0, 1, 2, 3, 4,
    };

    int16_t const right_data[6] = {
        3, 3, 3, 1, 0, -1,
    };

    auto stream = test::make_signal_stream(time::range{0, process_length}, left_data, time::range{1, 6}, 0, right_data,
                                           time::range{4, 6}, 1);

    auto module = make_signal_module<int16_t>(compare::kind::is_greater_equal);
    connect(module, compare::input::left, 0);
    connect(module, compare::input::right, 1);
    connect(module, compare::output::result, 2);

    module->process({0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const &events = stream.channel(2).events();

    XCTAssertEqual(events.size(), 1);

    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<boolean>();

    XCTAssertEqual(vec.size(), process_length);
    XCTAssertTrue(vec[0]);   // 0 >= 0
    XCTAssertFalse(vec[1]);  // -1 >= 0
    XCTAssertTrue(vec[2]);   // 0 >= 0
    XCTAssertTrue(vec[3]);   // 1 >= 0
    XCTAssertFalse(vec[4]);  // 2 >= 3
    XCTAssertTrue(vec[5]);   // 3 >= 3
    XCTAssertTrue(vec[6]);   // 4 >= 3
    XCTAssertFalse(vec[7]);  // 0 >= 1
    XCTAssertTrue(vec[8]);   // 0 >= 0
    XCTAssertTrue(vec[9]);   // 0 >= -1
    XCTAssertTrue(vec[10]);  // 0 >= 0
}

- (void)test_is_less {
    length_t const process_length = 11;

    int16_t const left_data[6] = {
        -1, 0, 1, 2, 3, 4,
    };

    int16_t const right_data[6] = {
        3, 3, 3, 1, 0, -1,
    };

    auto stream = test::make_signal_stream(time::range{0, process_length}, left_data, time::range{1, 6}, 0, right_data,
                                           time::range{4, 6}, 1);

    auto module = make_signal_module<int16_t>(compare::kind::is_less);
    connect(module, compare::input::left, 0);
    connect(module, compare::input::right, 1);
    connect(module, compare::output::result, 2);

    module->process({0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const &events = stream.channel(2).events();

    XCTAssertEqual(events.size(), 1);

    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<boolean>();

    XCTAssertEqual(vec.size(), process_length);
    XCTAssertFalse(vec[0]);   // 0 < 0
    XCTAssertTrue(vec[1]);    // -1 < 0
    XCTAssertFalse(vec[2]);   // 0 < 0
    XCTAssertFalse(vec[3]);   // 1 < 0
    XCTAssertTrue(vec[4]);    // 2 < 3
    XCTAssertFalse(vec[5]);   // 3 < 3
    XCTAssertFalse(vec[6]);   // 4 < 3
    XCTAssertTrue(vec[7]);    // 0 < 1
    XCTAssertFalse(vec[8]);   // 0 < 0
    XCTAssertFalse(vec[9]);   // 0 < -1
    XCTAssertFalse(vec[10]);  // 0 < 0
}

- (void)test_is_less_equal {
    length_t const process_length = 11;

    int16_t const left_data[6] = {
        -1, 0, 1, 2, 3, 4,
    };

    int16_t const right_data[6] = {
        3, 3, 3, 1, 0, -1,
    };

    auto stream = test::make_signal_stream(time::range{0, process_length}, left_data, time::range{1, 6}, 0, right_data,
                                           time::range{4, 6}, 1);

    auto module = make_signal_module<int16_t>(compare::kind::is_less_equal);
    connect(module, compare::input::left, 0);
    connect(module, compare::input::right, 1);
    connect(module, compare::output::result, 2);

    module->process({0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const &events = stream.channel(2).events();

    XCTAssertEqual(events.size(), 1);

    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<boolean>();

    XCTAssertEqual(vec.size(), process_length);
    XCTAssertTrue(vec[0]);   // 0 <= 0
    XCTAssertTrue(vec[1]);   // -1 <= 0
    XCTAssertTrue(vec[2]);   // 0 <= 0
    XCTAssertFalse(vec[3]);  // 1 <= 0
    XCTAssertTrue(vec[4]);   // 2 <= 3
    XCTAssertTrue(vec[5]);   // 3 <= 3
    XCTAssertFalse(vec[6]);  // 4 <= 3
    XCTAssertTrue(vec[7]);   // 0 <= 1
    XCTAssertTrue(vec[8]);   // 0 <= 0
    XCTAssertFalse(vec[9]);  // 0 <= -1
    XCTAssertTrue(vec[10]);  // 0 <= 0
}

@end
