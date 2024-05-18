//
//  number_to_signal_module_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/module/maker/number_to_signal_module.h>
#import <cpp-utils/boolean.h>

using namespace yas;
using namespace yas::proc;

@interface number_to_signal_module_tests : XCTestCase

@end

@implementation number_to_signal_module_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_process {
    channel_index_t const in_ch_idx = 2;
    channel_index_t const out_ch_idx = 5;
    length_t const process_length = 8;

    stream stream{sync_source{1, process_length}};

    {
        auto &channel = stream.add_channel(in_ch_idx);
        channel.insert_event(make_frame_time(1), number_event::make_shared<int8_t>(1));
        channel.insert_event(make_frame_time(3), number_event::make_shared<int8_t>(3));
        channel.insert_event(make_frame_time(10), number_event::make_shared<int8_t>(10));
        channel.insert_event(make_frame_time(13), number_event::make_shared<int8_t>(13));
    }

    auto module = make_number_to_signal_module<int8_t>();
    connect(module, number_to_signal::input::number, in_ch_idx);
    connect(module, number_to_signal::output::signal, out_ch_idx);

    module->process({0, process_length}, stream);

    {
        auto const &channel = stream.channel(out_ch_idx);
        auto const &signal_events = channel.filtered_events<int8_t, signal_event>();

        XCTAssertEqual(signal_events.size(), 1);
        XCTAssertEqual(signal_events.cbegin()->first, (time::range{0, process_length}));

        auto const &signal_event = signal_events.cbegin()->second;

        auto const *const data = signal_event->data<int8_t>();

        XCTAssertEqual(data[0], 0);
        XCTAssertEqual(data[1], 1);
        XCTAssertEqual(data[2], 1);
        XCTAssertEqual(data[3], 3);
        XCTAssertEqual(data[4], 3);
        XCTAssertEqual(data[5], 3);
        XCTAssertEqual(data[6], 3);
        XCTAssertEqual(data[7], 3);
    }

    {
        auto const &channel = stream.channel(in_ch_idx);

        XCTAssertEqual(channel.events().size(), 2);

        auto iterator = channel.events().cbegin();
        XCTAssertEqual(iterator->first, make_frame_time(10));
        ++iterator;
        XCTAssertEqual(iterator->first, make_frame_time(13));
    }

    stream.channel(out_ch_idx).erase_event_if([](auto const &) { return true; });

    XCTAssertEqual(stream.channel(out_ch_idx).events().size(), 0);

    module->process({process_length, process_length}, stream);

    {
        auto const &channel = stream.channel(out_ch_idx);
        auto const &signal_events = channel.filtered_events<int8_t, signal_event>();

        XCTAssertEqual(signal_events.size(), 1);
        XCTAssertEqual(signal_events.cbegin()->first, (time::range{process_length, process_length}));

        auto const &signal_event = signal_events.cbegin()->second;
        auto const *const data = signal_event->data<int8_t>();

        XCTAssertEqual(data[0], 3);
        XCTAssertEqual(data[1], 3);
        XCTAssertEqual(data[2], 10);
        XCTAssertEqual(data[3], 10);
        XCTAssertEqual(data[4], 10);
        XCTAssertEqual(data[5], 13);
        XCTAssertEqual(data[6], 13);
        XCTAssertEqual(data[7], 13);
    }
}

- (void)test_connect_input {
    auto module = make_number_to_signal_module<int32_t>();
    connect(module, number_to_signal::input::number, 13);

    auto const &connectors = module->input_connectors();
    XCTAssertEqual(connectors.size(), 1);
    XCTAssertEqual(connectors.cbegin()->first, to_connector_index(number_to_signal::input::number));
    XCTAssertEqual(connectors.cbegin()->second.channel_index, 13);
}

- (void)test_connect_output {
    auto module = make_number_to_signal_module<int32_t>();
    connect(module, number_to_signal::output::signal, 14);

    auto const &connectors = module->output_connectors();

    XCTAssertEqual(connectors.size(), 1);
    XCTAssertEqual(connectors.cbegin()->first, to_connector_index(number_to_signal::output::signal));
    XCTAssertEqual(connectors.cbegin()->second.channel_index, 14);
}

- (void)test_input_to_string {
    XCTAssertEqual(to_string(number_to_signal::input::number), "number");
}

- (void)test_output_to_string {
    XCTAssertEqual(to_string(number_to_signal::output::signal), "signal");
}

- (void)test_input_ostream {
    auto const values = {number_to_signal::input::number};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

- (void)test_output_ostream {
    auto const values = {number_to_signal::output::signal};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

@end
