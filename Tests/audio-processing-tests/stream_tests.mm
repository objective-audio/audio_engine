//
//  stream_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/stream/stream.h>

using namespace yas;
using namespace yas::proc;

@interface stream_tests : XCTestCase

@end

@implementation stream_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create_stream {
    proc::stream stream{sync_source{1, 2}};

    XCTAssertEqual(stream.sync_source(), (sync_source{1, 2}));
    XCTAssertEqual(stream.channel_count(), 0);
}

- (void)test_add_channel {
    proc::stream stream{sync_source{1, 1}};

    stream.add_channel(1);

    XCTAssertTrue(stream.has_channel(1));
    XCTAssertEqual(stream.channel_count(), 1);

    stream.add_channel(5);

    XCTAssertTrue(stream.has_channel(5));
    XCTAssertEqual(stream.channel_count(), 2);

    stream.add_channel(100);

    XCTAssertTrue(stream.has_channel(100));
    XCTAssertEqual(stream.channel_count(), 3);

    stream.add_channel(1);

    XCTAssertEqual(stream.channel_count(), 3);
    XCTAssertFalse(stream.has_channel(0));
}

- (void)test_remove_channel {
    proc::stream stream{sync_source{1, 1}};

    stream.add_channel(10);
    stream.add_channel(11);

    stream.remove_channel(10);

    XCTAssertEqual(stream.channel_count(), 1);
    XCTAssertFalse(stream.has_channel(10));
    XCTAssertTrue(stream.has_channel(11));
}

- (void)test_add_channel_return {
    proc::stream stream{sync_source{1, 1}};

    auto &returned_channel = stream.add_channel(1);

    XCTAssertEqual(returned_channel.events().size(), 0);
    XCTAssertEqual(&returned_channel, &stream.channel(1));
}

- (void)test_channel {
    proc::stream stream{sync_source{1, 2}};

    stream.add_channel(2);

    auto &channel = stream.channel(2);
    channel.insert_event({0, 2}, signal_event::make_shared(std::vector<int8_t>{5, 6}));

    auto const &const_stream = stream;
    auto const &const_channel = const_stream.channel(2);

    XCTAssertEqual(const_channel.events().size(), 1);

    auto const const_signal = const_channel.events().cbegin()->second.get<signal_event>();
    XCTAssertEqual(const_signal->vector<int8_t>()[0], 5);
    XCTAssertEqual(const_signal->vector<int8_t>()[1], 6);
}

- (void)test_channels {
    proc::stream stream{sync_source{1, 2}};

    stream.add_channel(0);

    XCTAssertEqual(stream.channels().size(), 1);
    XCTAssertEqual(stream.channels().count(0), 1);

    stream.add_channel(1);

    XCTAssertEqual(stream.channels().size(), 2);
    XCTAssertEqual(stream.channels().count(0), 1);
    XCTAssertEqual(stream.channels().count(1), 1);
}

@end
