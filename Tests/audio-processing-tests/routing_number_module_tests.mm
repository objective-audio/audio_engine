//
//  routing_number_module_tests.mm
//

#import <XCTest/XCTest.h>
#import <cpp-utils/boolean.h>
#import "utils/test_utils.h"

using namespace yas;
using namespace yas::proc;

@interface routing_number_module_tests : XCTestCase

@end

@implementation routing_number_module_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_make_number_module {
    XCTAssertTrue(make_number_module<double>(routing::kind::move));
    XCTAssertTrue(make_number_module<float>(routing::kind::move));
    XCTAssertTrue(make_number_module<int64_t>(routing::kind::move));
    XCTAssertTrue(make_number_module<int32_t>(routing::kind::move));
    XCTAssertTrue(make_number_module<int16_t>(routing::kind::move));
    XCTAssertTrue(make_number_module<int8_t>(routing::kind::move));
    XCTAssertTrue(make_number_module<uint64_t>(routing::kind::move));
    XCTAssertTrue(make_number_module<uint32_t>(routing::kind::move));
    XCTAssertTrue(make_number_module<uint16_t>(routing::kind::move));
    XCTAssertTrue(make_number_module<uint8_t>(routing::kind::move));
    XCTAssertTrue(make_number_module<boolean>(routing::kind::move));

    XCTAssertTrue(make_number_module<double>(routing::kind::copy));
    XCTAssertTrue(make_number_module<float>(routing::kind::copy));
    XCTAssertTrue(make_number_module<int64_t>(routing::kind::copy));
    XCTAssertTrue(make_number_module<int32_t>(routing::kind::copy));
    XCTAssertTrue(make_number_module<int16_t>(routing::kind::copy));
    XCTAssertTrue(make_number_module<int8_t>(routing::kind::copy));
    XCTAssertTrue(make_number_module<uint64_t>(routing::kind::copy));
    XCTAssertTrue(make_number_module<uint32_t>(routing::kind::copy));
    XCTAssertTrue(make_number_module<uint16_t>(routing::kind::copy));
    XCTAssertTrue(make_number_module<uint8_t>(routing::kind::copy));
    XCTAssertTrue(make_number_module<boolean>(routing::kind::copy));
}

- (void)test_move_number_process {
    length_t const process_length = 2;
    channel_index_t const input_ch_idx = 0;
    channel_index_t const output_ch_idx = 1;

    int8_t data[process_length] = {1, 2};

    auto module = make_number_module<int8_t>(routing::kind::move);
    connect(module, routing::input::value, input_ch_idx);
    connect(module, routing::output::value, output_ch_idx);

    auto stream = test::make_number_stream(process_length, data, time::range{0, process_length}, 0);

    module->process(time::range{0, process_length}, stream);

    auto const &input_events = stream.channel(input_ch_idx).events();
    XCTAssertEqual(input_events.size(), 0);

    auto const &output_events = stream.channel(output_ch_idx).filtered_events<int8_t, number_event>();
    XCTAssertEqual(output_events.size(), 2);

    auto event_iterator = output_events.cbegin();
    XCTAssertEqual((event_iterator++)->second->get<int8_t>(), 1);
    XCTAssertEqual((event_iterator++)->second->get<int8_t>(), 2);
}

- (void)test_move_number_process_part {
    length_t const process_length = 2;
    channel_index_t const input_ch_idx = 0;
    channel_index_t const output_ch_idx = 1;

    int8_t data[process_length] = {1, 2};

    auto module = make_number_module<int8_t>(routing::kind::move);
    connect(module, routing::input::value, input_ch_idx);
    connect(module, routing::output::value, output_ch_idx);

    auto stream = test::make_number_stream(process_length, data, time::range{0, process_length}, 0);

    module->process(time::range{1, 1}, stream);

    auto const &unprocessed_events = stream.channel(input_ch_idx).filtered_events<int8_t, number_event>();
    XCTAssertEqual(unprocessed_events.size(), 1);

    XCTAssertEqual(unprocessed_events.cbegin()->first, 0);
    XCTAssertEqual(unprocessed_events.cbegin()->second->get<int8_t>(), 1);

    auto const &processed_events = stream.channel(output_ch_idx).filtered_events<int8_t, number_event>();
    XCTAssertEqual(processed_events.size(), 1);

    XCTAssertEqual(processed_events.cbegin()->first, 1);
    XCTAssertEqual(processed_events.cbegin()->second->get<int8_t>(), 2);
}

- (void)test_copy_number_process {
    length_t const process_length = 2;
    channel_index_t const input_ch_idx = 0;
    channel_index_t const output_ch_idx = 1;

    int8_t data[process_length] = {1, 2};

    auto module = make_number_module<int8_t>(routing::kind::copy);
    connect(module, routing::input::value, input_ch_idx);
    connect(module, routing::output::value, output_ch_idx);

    auto stream = test::make_number_stream(process_length, data, time::range{0, process_length}, 0);

    module->process(time::range{0, process_length}, stream);

    auto const &input_events = stream.channel(input_ch_idx).filtered_events<int8_t, number_event>();
    XCTAssertEqual(input_events.size(), 2);

    auto input_iterator = input_events.cbegin();
    XCTAssertEqual((input_iterator++)->second->get<int8_t>(), 1);
    XCTAssertEqual((input_iterator++)->second->get<int8_t>(), 2);

    auto const &output_events = stream.channel(output_ch_idx).filtered_events<int8_t, number_event>();
    XCTAssertEqual(output_events.size(), 2);

    auto output_iterator = output_events.cbegin();
    XCTAssertEqual((output_iterator++)->second->get<int8_t>(), 1);
    XCTAssertEqual((output_iterator++)->second->get<int8_t>(), 2);
}

- (void)test_copy_number_process_part {
    length_t const process_length = 2;
    channel_index_t const input_ch_idx = 0;
    channel_index_t const output_ch_idx = 1;

    int8_t data[process_length] = {1, 2};

    auto module = make_number_module<int8_t>(routing::kind::copy);
    connect(module, routing::input::value, input_ch_idx);
    connect(module, routing::output::value, output_ch_idx);

    auto stream = test::make_number_stream(process_length, data, time::range{0, process_length}, 0);

    module->process(time::range{1, 1}, stream);

    auto const &input_events = stream.channel(input_ch_idx).filtered_events<int8_t, number_event>();
    XCTAssertEqual(input_events.size(), 2);

    auto input_iterator = input_events.cbegin();
    XCTAssertEqual(input_iterator->first, 0);
    XCTAssertEqual((input_iterator++)->second->get<int8_t>(), 1);
    XCTAssertEqual(input_iterator->first, 1);
    XCTAssertEqual((input_iterator++)->second->get<int8_t>(), 2);

    auto const &output_events = stream.channel(output_ch_idx).filtered_events<int8_t, number_event>();
    XCTAssertEqual(output_events.size(), 1);

    auto output_iterator = output_events.cbegin();
    XCTAssertEqual(output_iterator->first, 1);
    XCTAssertEqual(output_iterator->second->get<int8_t>(), 2);
}

- (void)test_connect_input {
    auto module = make_number_module<int8_t>(routing::kind::copy);
    connect(module, routing::input::value, 15);

    auto const &connectors = module->input_connectors();
    XCTAssertEqual(connectors.size(), 1);
    XCTAssertEqual(connectors.cbegin()->first, to_connector_index(routing::input::value));
    XCTAssertEqual(connectors.cbegin()->second.channel_index, 15);
}

- (void)test_connect_output {
    auto module = make_number_module<int8_t>(routing::kind::move);
    connect(module, routing::output::value, 16);

    auto const &connectors = module->output_connectors();

    XCTAssertEqual(connectors.size(), 1);
    XCTAssertEqual(connectors.cbegin()->first, to_connector_index(routing::output::value));
    XCTAssertEqual(connectors.cbegin()->second.channel_index, 16);
}

- (void)test_input_to_string {
    XCTAssertEqual(to_string(routing::input::value), "value");
}

- (void)test_output_to_string {
    XCTAssertEqual(to_string(routing::output::value), "value");
}

- (void)test_input_ostream {
    auto const values = {routing::input::value};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

- (void)test_output_ostream {
    auto const values = {routing::output::value};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

@end
