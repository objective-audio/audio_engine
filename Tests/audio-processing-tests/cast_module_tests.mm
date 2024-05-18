//
//  cast_module_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/module/maker/cast_module.h>

using namespace yas;
using namespace yas::proc;

@interface cast_module_tests : XCTestCase

@end

@implementation cast_module_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create {
    auto module = cast::make_signal_module<int8_t, float>();

    XCTAssertTrue(module);
}

- (void)test_process_signal_diff_channel {
    auto constant_module1 = make_signal_module(int8_t(1));
    constant_module1->connect_output(to_connector_index(constant::output::value), 0);

    auto constant_module2 = make_signal_module(int8_t(2));
    constant_module2->connect_output(to_connector_index(constant::output::value), 0);

    auto cast_module = cast::make_signal_module<int8_t, float>();
    connect(cast_module, cast::input::value, 0);
    connect(cast_module, cast::output::value, 1);

    stream stream{sync_source{1, 2}};

    constant_module1->process({0, 1}, stream);
    constant_module2->process({1, 1}, stream);
    cast_module->process({0, 2}, stream);

    XCTAssertTrue(stream.has_channel(1));

    auto const &channel = stream.channel(1);
    XCTAssertEqual(channel.events().size(), 1);

    auto &event = channel.events().cbegin()->second;
    auto const signal = event.get<signal_event>();
    XCTAssertTrue(signal);
    XCTAssertTrue(signal->sample_type() == typeid(float));
    XCTAssertEqual(signal->size(), 2);
    auto const *data = signal->data<float>();
    XCTAssertEqual(data[0], 1.0);
    XCTAssertEqual(data[1], 2.0);
}

- (void)test_process_signal_same_channel {
    auto constant_module1 = make_signal_module(int8_t(32));
    constant_module1->connect_output(to_connector_index(constant::output::value), 2);

    auto constant_module2 = make_signal_module(int8_t(64));
    constant_module2->connect_output(to_connector_index(constant::output::value), 2);

    auto cast_module = cast::make_signal_module<int8_t, double>();
    connect(cast_module, cast::input::value, 2);
    connect(cast_module, cast::output::value, 2);

    stream stream{sync_source{1, 2}};

    constant_module1->process({0, 1}, stream);
    constant_module2->process({1, 1}, stream);
    cast_module->process({0, 2}, stream);

    XCTAssertTrue(stream.has_channel(2));

    auto const &channel = stream.channel(2);
    XCTAssertEqual(channel.events().size(), 1);

    auto const filtered_events = channel.filtered_events<double, signal_event>();
    XCTAssertEqual(filtered_events.size(), 1);

    auto const &pair = *filtered_events.cbegin();

    XCTAssertTrue((pair.first == time::range{0, 2}));
    auto const &signal = pair.second;
    XCTAssertTrue(signal->sample_type() == typeid(double));
    XCTAssertEqual(signal->size(), 2);
    auto const *data = signal->data<double>();
    XCTAssertEqual(data[0], 32.0);
    XCTAssertEqual(data[1], 64.0);
}

- (void)test_process_number_diff_channel {
    auto cast_module = cast::make_number_module<int8_t, float>();
    connect(cast_module, cast::input::value, 0);
    connect(cast_module, cast::output::value, 1);

    stream stream{sync_source{1, 2}};

    {
        auto &channel0 = stream.add_channel(0);
        channel0.insert_event(make_frame_time(0), number_event::make_shared(int8_t(0)));
        channel0.insert_event(make_frame_time(1), number_event::make_shared(int8_t(1)));
        channel0.insert_event(make_frame_time(2), number_event::make_shared(int8_t(2)));
        channel0.insert_event(make_frame_time(0), number_event::make_shared(int16_t(-1)));
        auto &channel1 = stream.add_channel(1);
        channel1.insert_event(make_frame_time(0), number_event::make_shared(int8_t(10)));
        auto &channel2 = stream.add_channel(2);
        channel2.insert_event(make_frame_time(0), number_event::make_shared(int8_t(20)));
    }

    cast_module->process({0, 2}, stream);

    XCTAssertTrue(stream.has_channel(0));
    auto const &channel0 = stream.channel(0);
    XCTAssertEqual(channel0.events().size(), 2);
    auto it = channel0.events().cbegin();
    XCTAssertEqual(it->first, make_frame_time(0));
    XCTAssertTrue(it->second.is_equal(number_event::make_shared(int16_t(-1))));
    ++it;
    XCTAssertEqual(it->first, make_frame_time(2));
    XCTAssertTrue(it->second.is_equal(number_event::make_shared(int8_t(2))));

    XCTAssertTrue(stream.has_channel(1));
    auto const &channel1 = stream.channel(1);
    XCTAssertEqual(channel1.events().size(), 3);
    it = channel1.events().cbegin();
    XCTAssertEqual(it->first, make_frame_time(0));
    XCTAssertTrue(it->second.is_equal(number_event::make_shared(int8_t(10))));
    ++it;
    XCTAssertEqual(it->first, make_frame_time(0));
    XCTAssertTrue(it->second.is_equal(number_event::make_shared(float(0.0f))));
    ++it;
    XCTAssertEqual(it->first, make_frame_time(1));
    XCTAssertTrue(it->second.is_equal(number_event::make_shared(float(1.0f))));

    XCTAssertTrue(stream.has_channel(2));
    auto const &channel2 = stream.channel(2);
    XCTAssertEqual(channel2.events().size(), 1);
    it = channel2.events().cbegin();
    XCTAssertEqual(it->first, make_frame_time(0));
    XCTAssertTrue(it->second.is_equal(number_event::make_shared(int8_t(20))));
}

- (void)test_process_number_same_channel {
    auto cast_module = cast::make_number_module<int32_t, double>();
    connect(cast_module, cast::input::value, 3);
    connect(cast_module, cast::output::value, 3);

    stream stream{sync_source{1, 2}};

    {
        auto &channel = stream.add_channel(3);
        channel.insert_event(make_frame_time(0), number_event::make_shared(int32_t(0)));
        channel.insert_event(make_frame_time(1), number_event::make_shared(int32_t(1)));
        channel.insert_event(make_frame_time(2), number_event::make_shared(int32_t(2)));
        channel.insert_event(make_frame_time(0), number_event::make_shared(int16_t(-1)));
    }

    cast_module->process({0, 2}, stream);

    XCTAssertTrue(stream.has_channel(3));
    auto const &channel = stream.channel(3);
    XCTAssertEqual(channel.events().size(), 4);

    auto it = channel.events().cbegin();
    XCTAssertEqual(it->first, make_frame_time(0));
    XCTAssertTrue(it->second.is_equal(number_event::make_shared(int16_t(-1))));
    ++it;
    XCTAssertEqual(it->first, make_frame_time(0));
    XCTAssertTrue(it->second.is_equal(number_event::make_shared(double(0.0))));
    ++it;
    XCTAssertEqual(it->first, make_frame_time(1));
    XCTAssertTrue(it->second.is_equal(number_event::make_shared(double(1.0))));
    ++it;
    XCTAssertEqual(it->first, make_frame_time(2));
    XCTAssertTrue(it->second.is_equal(number_event::make_shared(int32_t(2))));
}

- (void)test_connect_input {
    auto module = cast::make_number_module<int32_t, double>();
    connect(module, cast::input::value, 3);

    auto const &connectors = module->input_connectors();
    XCTAssertEqual(connectors.size(), 1);
    XCTAssertEqual(connectors.cbegin()->first, to_connector_index(cast::input::value));
    XCTAssertEqual(connectors.cbegin()->second.channel_index, 3);
}

- (void)test_connect_output {
    auto module = cast::make_number_module<int32_t, double>();
    connect(module, cast::output::value, 4);

    auto const &connectors = module->output_connectors();

    XCTAssertEqual(connectors.size(), 1);
    XCTAssertEqual(connectors.cbegin()->first, to_connector_index(cast::output::value));
    XCTAssertEqual(connectors.cbegin()->second.channel_index, 4);
}

- (void)test_input_to_string {
    XCTAssertEqual(to_string(cast::input::value), "value");
}

- (void)test_output_to_string {
    XCTAssertEqual(to_string(cast::output::value), "value");
}

- (void)test_input_ostream {
    auto const values = {cast::input::value};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

- (void)test_output_ostream {
    auto const values = {cast::output::value};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

@end
