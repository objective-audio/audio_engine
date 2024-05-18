//
//  math2_modules_tests.mm
//

#import <XCTest/XCTest.h>
#import "utils/test_utils.h"

@interface math2_modules_tests : XCTestCase

@end

@implementation math2_modules_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create_signal_modules {
    XCTAssertTrue(make_signal_module<int16_t>(math2::kind::plus));
    XCTAssertTrue(make_signal_module<int16_t>(math2::kind::minus));
    XCTAssertTrue(make_signal_module<int16_t>(math2::kind::multiply));
    XCTAssertTrue(make_signal_module<int16_t>(math2::kind::divide));
    XCTAssertTrue(make_signal_module<int16_t>(math2::kind::atan2));
    XCTAssertTrue(make_signal_module<int16_t>(math2::kind::pow));
    XCTAssertTrue(make_signal_module<int16_t>(math2::kind::hypot));
}

- (void)test_plus_process {
    length_t const process_length = 5;

    int16_t const left_data[2] = {1, 1};

    int16_t const right_data[2] = {10, 10};

    auto stream = test::make_signal_stream(time::range{0, process_length}, left_data, time::range{1, 2}, 0, right_data,
                                           time::range{2, 2}, 1);

    auto module = make_signal_module<int16_t>(math2::kind::plus);
    connect(module, math2::input::left, 0);
    connect(module, math2::input::right, 1);
    connect(module, math2::output::result, 2);

    module->process({0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const &events = stream.channel(2).events();

    XCTAssertEqual(events.size(), 1);

    auto const signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<int16_t>();

    XCTAssertEqual(vec.size(), process_length);
    XCTAssertEqual(vec[0], 0);
    XCTAssertEqual(vec[1], 1);
    XCTAssertEqual(vec[2], 11);
    XCTAssertEqual(vec[3], 10);
    XCTAssertEqual(vec[4], 0);
}

- (void)test_minus_process {
    length_t const process_length = 5;

    int16_t const left_data[2] = {100, 100};

    int16_t const right_data[2] = {10, 10};

    auto stream = test::make_signal_stream(time::range{0, process_length}, left_data, time::range{1, 2}, 0, right_data,
                                           time::range{2, 2}, 1);

    auto module = make_signal_module<int16_t>(math2::kind::minus);
    connect(module, math2::input::left, 0);
    connect(module, math2::input::right, 1);
    connect(module, math2::output::result, 2);

    module->process({0, 5}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const &events = stream.channel(2).events();

    XCTAssertEqual(events.size(), 1);

    auto const &signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<int16_t>();

    XCTAssertEqual(vec.size(), 5);
    XCTAssertEqual(vec[0], 0);
    XCTAssertEqual(vec[1], 100);
    XCTAssertEqual(vec[2], 90);
    XCTAssertEqual(vec[3], -10);
    XCTAssertEqual(vec[4], 0);
}

- (void)test_multiply_process {
    length_t const process_length = 5;

    int16_t const left_data[2] = {2, 2};

    int16_t const right_data[2] = {4, 4};

    auto stream = test::make_signal_stream(time::range{0, process_length}, left_data, time::range{1, 2}, 0, right_data,
                                           time::range{2, 2}, 1);

    auto module = make_signal_module<int16_t>(math2::kind::multiply);
    connect(module, math2::input::left, 0);
    connect(module, math2::input::right, 1);
    connect(module, math2::output::result, 2);

    module->process({0, 5}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const &events = stream.channel(2).events();

    XCTAssertEqual(events.size(), 1);

    auto const &signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<int16_t>();

    XCTAssertEqual(vec.size(), 5);
    XCTAssertEqual(vec[0], 0);
    XCTAssertEqual(vec[1], 0);
    XCTAssertEqual(vec[2], 8);
    XCTAssertEqual(vec[3], 0);
    XCTAssertEqual(vec[4], 0);
}

- (void)test_divide_process {
    length_t const process_length = 5;

    int16_t const left_data[2] = {4, 4};

    int16_t const right_data[2] = {2, 2};

    auto stream = test::make_signal_stream(time::range{0, process_length}, left_data, time::range{1, 2}, 0, right_data,
                                           time::range{2, 2}, 1);

    auto module = make_signal_module<int16_t>(math2::kind::divide);
    connect(module, math2::input::left, 0);
    connect(module, math2::input::right, 1);
    connect(module, math2::output::result, 2);

    module->process({0, 5}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const &events = stream.channel(2).events();

    XCTAssertEqual(events.size(), 1);

    auto const &signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<int16_t>();

    XCTAssertEqual(vec.size(), 5);
    XCTAssertEqual(vec[0], 0);
    XCTAssertEqual(vec[1], 0);
    XCTAssertEqual(vec[2], 2);
    XCTAssertEqual(vec[3], 0);
    XCTAssertEqual(vec[4], 0);
}

- (void)test_atan2 {
    length_t const process_length = 9;

    double const left_data[6] = {1.0, 1.0, 1.0, -1.0, -1.0, -1.0};

    double const right_data[6] = {1.0, -1.0, 1.0, -1.0, 1.0, -1.0};

    auto stream = test::make_signal_stream(time::range{0, process_length}, left_data, time::range{1, 6}, 0, right_data,
                                           time::range{2, 6}, 1);

    auto module = make_signal_module<double>(math2::kind::atan2);
    connect(module, math2::input::left, 0);
    connect(module, math2::input::right, 1);
    connect(module, math2::output::result, 2);

    module->process({0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const &events = stream.channel(2).events();

    XCTAssertEqual(events.size(), 1);

    auto const &signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqual(vec.size(), process_length);
    XCTAssertEqual(vec[0], std::atan2(0.0, 0.0));
    XCTAssertEqual(vec[1], std::atan2(1.0, 0.0));
    XCTAssertEqual(vec[2], std::atan2(1.0, 1.0));
    XCTAssertEqual(vec[3], std::atan2(1.0, -1.0));
    XCTAssertEqual(vec[4], std::atan2(-1.0, 1.0));
    XCTAssertEqual(vec[5], std::atan2(-1.0, -1.0));
    XCTAssertEqual(vec[6], std::atan2(-1.0, 1.0));
    XCTAssertEqual(vec[7], std::atan2(0.0, -1.0));
    XCTAssertEqual(vec[8], std::atan2(0.0, 0.0));
}

- (void)test_pow {
    length_t const process_length = 5;

    double const left_data[2] = {2.0, 2.0};

    double const right_data[2] = {4.0, 4.0};

    auto stream = test::make_signal_stream(time::range{0, process_length}, left_data, time::range{1, 2}, 0, right_data,
                                           time::range{2, 2}, 1);

    auto module = make_signal_module<double>(math2::kind::pow);
    connect(module, math2::input::left, 0);
    connect(module, math2::input::right, 1);
    connect(module, math2::output::result, 2);

    module->process({0, 5}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const &events = stream.channel(2).events();

    XCTAssertEqual(events.size(), 1);

    auto const &signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqual(vec.size(), 5);
    XCTAssertEqual(vec[0], std::pow(0.0, 0.0));
    XCTAssertEqual(vec[1], std::pow(2.0, 0.0));
    XCTAssertEqual(vec[2], std::pow(2.0, 4.0));
    XCTAssertEqual(vec[3], std::pow(0.0, 4.0));
    XCTAssertEqual(vec[4], std::pow(0.0, 0.0));
}

- (void)test_hypot {
    length_t const process_length = 5;

    double const left_data[2] = {1.0, 1.0};

    double const right_data[2] = {3.0, 3.0};

    auto stream = test::make_signal_stream(time::range{0, process_length}, left_data, time::range{1, 2}, 0, right_data,
                                           time::range{2, 2}, 1);

    auto module = make_signal_module<double>(math2::kind::hypot);
    connect(module, math2::input::left, 0);
    connect(module, math2::input::right, 1);
    connect(module, math2::output::result, 2);

    module->process({0, 5}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const &events = stream.channel(2).events();

    XCTAssertEqual(events.size(), 1);

    auto const &signal = events.cbegin()->second.get<signal_event>();
    auto const &vec = signal->vector<double>();

    XCTAssertEqual(vec.size(), 5);
    XCTAssertEqual(vec[0], std::hypot(0.0, 0.0));
    XCTAssertEqual(vec[1], std::hypot(1.0, 0.0));
    XCTAssertEqual(vec[2], std::hypot(1.0, 3.0));
    XCTAssertEqual(vec[3], std::hypot(0.0, 3.0));
    XCTAssertEqual(vec[4], std::hypot(0.0, 0.0));
}

@end
