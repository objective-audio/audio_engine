//
//  compare_number_modules_tests.mm
//

#import <XCTest/XCTest.h>
#import <cpp-utils/boolean.h>
#import "utils/test_utils.h"

using namespace yas;
using namespace yas::proc;

@interface compare_number_modules_tests : XCTestCase

@end

@implementation compare_number_modules_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_make_number_module {
    XCTAssertTrue(make_number_module<int16_t>(compare::kind::is_equal));
    XCTAssertTrue(make_number_module<int16_t>(compare::kind::is_not_equal));
    XCTAssertTrue(make_number_module<int16_t>(compare::kind::is_greater));
    XCTAssertTrue(make_number_module<int16_t>(compare::kind::is_greater_equal));
    XCTAssertTrue(make_number_module<int16_t>(compare::kind::is_less));
    XCTAssertTrue(make_number_module<int16_t>(compare::kind::is_less_equal));
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

    auto stream =
        test::make_number_stream(process_length, left_data, time::range{1, 3}, 0, right_data, time::range{2, 3}, 1);

    auto module = make_number_module<int16_t>(compare::kind::is_equal);
    connect(module, compare::input::left, 0);
    connect(module, compare::input::right, 1);
    connect(module, compare::output::result, 2);

    module->process({0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const events = stream.channel(2).filtered_events<boolean, number_event>();

    XCTAssertEqual(events.size(), 4);

    auto event_iterator = events.cbegin();

    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 1 == 0
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 2 == 2
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 3 == 2
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 0 == 2
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

    auto stream =
        test::make_number_stream(process_length, left_data, time::range{1, 3}, 0, right_data, time::range{2, 3}, 1);

    auto module = make_number_module<int16_t>(compare::kind::is_not_equal);
    connect(module, compare::input::left, 0);
    connect(module, compare::input::right, 1);
    connect(module, compare::output::result, 2);

    module->process({0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const events = stream.channel(2).filtered_events<boolean, number_event>();

    XCTAssertEqual(events.size(), 4);

    auto event_iterator = events.cbegin();

    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 1 != 0
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 2 != 2
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 3 != 2
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 0 != 2
}

- (void)test_is_greater {
    length_t const process_length = 11;

    int16_t const left_data[7] = {
        -1, 0, 1, 2, 3, 4, 0,
    };

    int16_t const right_data[6] = {
        3, 3, 3, 1, 0, -1,
    };

    auto stream =
        test::make_number_stream(process_length, left_data, time::range{1, 7}, 0, right_data, time::range{4, 6}, 1);

    auto module = make_number_module<int16_t>(compare::kind::is_greater);
    connect(module, compare::input::left, 0);
    connect(module, compare::input::right, 1);
    connect(module, compare::output::result, 2);

    module->process({0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const events = stream.channel(2).filtered_events<boolean, number_event>();

    XCTAssertEqual(events.size(), 9);

    auto event_iterator = events.cbegin();

    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // -1 > 0
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 0 > 0
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 1 > 0
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 2 > 3
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 3 > 3
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 4 > 3
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 0 > 1
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 0 > 0
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 0 > -1
}

- (void)test_is_greater_equal {
    length_t const process_length = 11;

    int16_t const left_data[7] = {
        -1, 0, 1, 2, 3, 4, 0,
    };

    int16_t const right_data[6] = {
        3, 3, 3, 1, 0, -1,
    };

    auto stream =
        test::make_number_stream(process_length, left_data, time::range{1, 7}, 0, right_data, time::range{4, 6}, 1);

    auto module = make_number_module<int16_t>(compare::kind::is_greater_equal);
    connect(module, compare::input::left, 0);
    connect(module, compare::input::right, 1);
    connect(module, compare::output::result, 2);

    module->process({0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const events = stream.channel(2).filtered_events<boolean, number_event>();

    XCTAssertEqual(events.size(), 9);

    auto event_iterator = events.cbegin();

    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // -1 >= 0
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 0 >= 0
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 1 >= 0
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 2 >= 3
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 3 >= 3
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 4 >= 3
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 0 >= 1
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 0 >= 0
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 0 >= -1
}

- (void)test_is_less {
    length_t const process_length = 11;

    int16_t const left_data[7] = {
        -1, 0, 1, 2, 3, 4, 0,
    };

    int16_t const right_data[6] = {
        3, 3, 3, 1, 0, -1,
    };

    auto stream =
        test::make_number_stream(process_length, left_data, time::range{1, 7}, 0, right_data, time::range{4, 6}, 1);

    auto module = make_number_module<int16_t>(compare::kind::is_less);
    connect(module, compare::input::left, 0);
    connect(module, compare::input::right, 1);
    connect(module, compare::output::result, 2);

    module->process({0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const events = stream.channel(2).filtered_events<boolean, number_event>();

    XCTAssertEqual(events.size(), 9);

    auto event_iterator = events.cbegin();

    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // -1 < 0
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 0 < 0
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 1 < 0
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 2 < 3
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 3 < 3
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 4 < 3
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 0 < 1
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 0 < 0
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 0 < -1
}

- (void)test_is_less_equal {
    length_t const process_length = 11;

    int16_t const left_data[7] = {
        -1, 0, 1, 2, 3, 4, 0,
    };

    int16_t const right_data[6] = {
        3, 3, 3, 1, 0, -1,
    };

    auto stream =
        test::make_number_stream(process_length, left_data, time::range{1, 7}, 0, right_data, time::range{4, 6}, 1);

    auto module = make_number_module<int16_t>(compare::kind::is_less_equal);
    connect(module, compare::input::left, 0);
    connect(module, compare::input::right, 1);
    connect(module, compare::output::result, 2);

    module->process({0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const events = stream.channel(2).filtered_events<boolean, number_event>();

    XCTAssertEqual(events.size(), 9);

    auto event_iterator = events.cbegin();

    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // -1 <= 0
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 0 <= 0
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 1 <= 0
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 2 <= 3
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 3 <= 3
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 4 <= 3
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 0 <= 1
    XCTAssertTrue((event_iterator++)->second->get<boolean>());   // 0 <= 0
    XCTAssertFalse((event_iterator++)->second->get<boolean>());  // 0 <= -1
}

- (void)test_connect_input {
    auto module = make_number_module<int16_t>(compare::kind::is_equal);
    connect(module, compare::input::left, 5);

    auto const &connectors = module->input_connectors();
    XCTAssertEqual(connectors.size(), 1);
    XCTAssertEqual(connectors.cbegin()->first, to_connector_index(compare::input::left));
    XCTAssertEqual(connectors.cbegin()->second.channel_index, 5);
}

- (void)test_connect_output {
    auto module = make_number_module<int16_t>(compare::kind::is_equal);
    connect(module, compare::output::result, 6);

    auto const &connectors = module->output_connectors();

    XCTAssertEqual(connectors.size(), 1);
    XCTAssertEqual(connectors.cbegin()->first, to_connector_index(compare::output::result));
    XCTAssertEqual(connectors.cbegin()->second.channel_index, 6);
}

- (void)test_input_to_string {
    XCTAssertEqual(to_string(compare::input::left), "left");
    XCTAssertEqual(to_string(compare::input::right), "right");
}

- (void)test_output_to_string {
    XCTAssertEqual(to_string(compare::output::result), "result");
}

- (void)test_input_ostream {
    auto const values = {compare::input::left, compare::input::right};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

- (void)test_output_ostream {
    auto const values = {compare::output::result};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

@end
