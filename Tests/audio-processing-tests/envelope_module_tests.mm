//
//  envelope_module_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/module/maker/envelope_module.h>

using namespace yas;
using namespace yas::proc;

@interface envelope_module_tests : XCTestCase

@end

@implementation envelope_module_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_make_signal_module {
    XCTAssertTrue(proc::envelope::make_signal_module<int8_t>({}, 0));
}

- (void)test_process {
    length_t const process_length = 5;
    channel_index_t const ch_idx = 10;

    stream stream{sync_source{1, process_length}};

    envelope::anchors_t<int8_t> anchors;
    anchors.emplace(1, 2);
    anchors.emplace(3, 4);

    auto module = envelope::make_signal_module(std::move(anchors), 0);
    connect(module, envelope::output::value, ch_idx);

    module->process(time::range{0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(ch_idx));

    auto const &channel = stream.channel(ch_idx);

    auto const &time = channel.events().cbegin()->first;
    auto const &time_range = time.get<time::range>();

    XCTAssertEqual(time_range, time::range(0, process_length));

    auto const &signal = channel.events().cbegin()->second.get<signal_event>();
    auto *data = signal->data<int8_t>();

    XCTAssertEqual(data[0], 2);
    XCTAssertEqual(data[1], 2);
    XCTAssertEqual(data[2], 3);
    XCTAssertEqual(data[3], 4);
    XCTAssertEqual(data[4], 4);
}

- (void)test_process_empty {
    length_t const process_length = 1;
    channel_index_t const ch_idx = 11;

    stream stream{sync_source{1, process_length}};

    envelope::anchors_t<int8_t> anchors;

    auto module = envelope::make_signal_module(std::move(anchors), 0);
    connect(module, envelope::output::value, ch_idx);

    module->process(time::range{0, process_length}, stream);

    XCTAssertTrue(stream.has_channel(ch_idx));

    auto const &channel = stream.channel(ch_idx);

    auto const &time = channel.events().cbegin()->first;
    auto const &time_range = time.get<time::range>();

    XCTAssertEqual(time_range, time::range(0, process_length));

    auto const &signal = channel.events().cbegin()->second.get<signal_event>();
    auto *data = signal->data<int8_t>();

    XCTAssertEqual(data[0], 0);
}

- (void)test_process_offset {
    length_t const process_length = 5;
    channel_index_t const ch_idx = 10;
    frame_index_t const offset = 100;

    stream stream{sync_source{1, process_length}};

    envelope::anchors_t<int8_t> anchors;
    anchors.emplace(1, 2);
    anchors.emplace(3, 4);

    auto module = envelope::make_signal_module(std::move(anchors), offset);
    connect(module, envelope::output::value, ch_idx);

    module->process(time::range{offset, process_length}, stream);

    XCTAssertTrue(stream.has_channel(ch_idx));

    auto const &channel = stream.channel(ch_idx);

    auto const &time = channel.events().cbegin()->first;
    auto const &time_range = time.get<time::range>();

    XCTAssertEqual(time_range, time::range(offset, process_length));

    auto const &signal = channel.events().cbegin()->second.get<signal_event>();
    auto *data = signal->data<int8_t>();

    XCTAssertEqual(data[0], 2);
    XCTAssertEqual(data[1], 2);
    XCTAssertEqual(data[2], 3);
    XCTAssertEqual(data[3], 4);
    XCTAssertEqual(data[4], 4);
}

@end
