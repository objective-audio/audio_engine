//
//  generator_modules_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/module/maker/generator_modules.h>

using namespace yas;
using namespace yas::proc;

@interface generator_modules_tests : XCTestCase

@end

@implementation generator_modules_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_second {
    channel_index_t const ch_idx = 8;
    sample_rate_t const sr = 8;
    length_t const process_length = sr * 2;

    stream stream{sync_source{sr, 20}};

    auto module = make_signal_module<double>(generator::kind::second, 0);
    module->connect_output(to_connector_index(generator::output::value), ch_idx);

    module->process(time::range{0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(ch_idx));

    auto const &channel = stream.channel(ch_idx);

    auto const &time = channel.events().cbegin()->first;
    auto const &time_range = time.get<time::range>();

    XCTAssertEqual(time_range.frame, 0);
    XCTAssertEqual(time_range.length, process_length);

    auto const &signal = channel.events().cbegin()->second.get<signal_event>();
    auto *data = signal->data<double>();

    XCTAssertEqual(data[0], 0.0);
    XCTAssertEqual(data[1], 0.125);
    XCTAssertEqual(data[2], 0.25);
    XCTAssertEqual(data[3], 0.375);
    XCTAssertEqual(data[4], 0.5);
    XCTAssertEqual(data[5], 0.625);
    XCTAssertEqual(data[6], 0.75);
    XCTAssertEqual(data[7], 0.875);
    XCTAssertEqual(data[8], 1.0);
    XCTAssertEqual(data[9], 1.125);
    XCTAssertEqual(data[10], 1.25);
    XCTAssertEqual(data[11], 1.375);
    XCTAssertEqual(data[12], 1.5);
    XCTAssertEqual(data[13], 1.625);
    XCTAssertEqual(data[14], 1.75);
    XCTAssertEqual(data[15], 1.875);
}

- (void)test_frame {
    channel_index_t const ch_idx = 9;
    sample_rate_t const sr = 8;
    length_t const process_length = sr * 2;

    stream stream{sync_source{sr, 20}};

    auto module = make_signal_module<int64_t>(generator::kind::frame, 0);
    module->connect_output(to_connector_index(generator::output::value), ch_idx);

    module->process(time::range{0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(ch_idx));

    auto const &channel = stream.channel(ch_idx);

    auto const &time = channel.events().cbegin()->first;
    auto const &time_range = time.get<time::range>();

    XCTAssertEqual(time_range.frame, 0);
    XCTAssertEqual(time_range.length, process_length);

    auto const &signal = channel.events().cbegin()->second.get<signal_event>();
    auto *data = signal->data<int64_t>();

    XCTAssertEqual(data[0], 0);
    XCTAssertEqual(data[1], 1);
    XCTAssertEqual(data[2], 2);
    XCTAssertEqual(data[3], 3);
    XCTAssertEqual(data[4], 4);
    XCTAssertEqual(data[5], 5);
    XCTAssertEqual(data[6], 6);
    XCTAssertEqual(data[7], 7);
    XCTAssertEqual(data[8], 8);
    XCTAssertEqual(data[9], 9);
    XCTAssertEqual(data[10], 10);
    XCTAssertEqual(data[11], 11);
    XCTAssertEqual(data[12], 12);
    XCTAssertEqual(data[13], 13);
    XCTAssertEqual(data[14], 14);
    XCTAssertEqual(data[15], 15);
}

- (void)test_offset {
    channel_index_t const ch_idx = 10;
    sample_rate_t const sr = 8;
    length_t const process_length = sr * 2;

    stream stream{sync_source{sr, 20}};

    auto module = make_signal_module<int64_t>(generator::kind::frame, 100);
    module->connect_output(to_connector_index(generator::output::value), ch_idx);

    module->process(time::range{0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(ch_idx));

    auto const &channel = stream.channel(ch_idx);

    auto const &time = channel.events().cbegin()->first;
    auto const &time_range = time.get<time::range>();

    XCTAssertEqual(time_range.frame, 0);
    XCTAssertEqual(time_range.length, process_length);

    auto const &signal = channel.events().cbegin()->second.get<signal_event>();
    auto *data = signal->data<int64_t>();

    XCTAssertEqual(data[0], 100);
    XCTAssertEqual(data[1], 101);
    XCTAssertEqual(data[2], 102);
    XCTAssertEqual(data[3], 103);
    XCTAssertEqual(data[4], 104);
    XCTAssertEqual(data[5], 105);
    XCTAssertEqual(data[6], 106);
    XCTAssertEqual(data[7], 107);
    XCTAssertEqual(data[8], 108);
    XCTAssertEqual(data[9], 109);
    XCTAssertEqual(data[10], 110);
    XCTAssertEqual(data[11], 111);
    XCTAssertEqual(data[12], 112);
    XCTAssertEqual(data[13], 113);
    XCTAssertEqual(data[14], 114);
    XCTAssertEqual(data[15], 115);
}

- (void)test_connect_output {
    auto module = make_number_module<int32_t>(1);
    connect(module, generator::output::value, 9);

    auto const &connectors = module->output_connectors();

    XCTAssertEqual(connectors.size(), 1);
    XCTAssertEqual(connectors.cbegin()->first, to_connector_index(generator::output::value));
    XCTAssertEqual(connectors.cbegin()->second.channel_index, 9);
}

- (void)test_output_to_string {
    XCTAssertEqual(to_string(generator::output::value), "value");
}

- (void)test_output_ostream {
    auto const values = {generator::output::value};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

@end
