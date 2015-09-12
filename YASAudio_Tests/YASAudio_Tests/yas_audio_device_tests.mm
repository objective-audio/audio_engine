//
//  yas_audio_device_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

@interface yas_audio_device_tests : XCTestCase

@end

@implementation yas_audio_device_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testAudioChannelRouteFull
{
    const UInt32 source_bus = 0;
    const UInt32 source_channel = 1;
    const UInt32 dest_bus = 2;
    const UInt32 dest_channel = 3;

    auto channel_route = yas::channel_route::create(source_bus, source_channel, dest_bus, dest_channel);

    XCTAssertEqual(channel_route->source_bus(), source_bus);
    XCTAssertEqual(channel_route->source_channel(), source_channel);
    XCTAssertEqual(channel_route->destination_bus(), dest_bus);
    XCTAssertEqual(channel_route->destination_channel(), dest_channel);
}

- (void)testAudioChannelRouteSimple
{
    const UInt32 bus_idx = 4;
    const UInt32 ch_idx = 5;

    auto channel_route = yas::channel_route::create(bus_idx, ch_idx);

    XCTAssertEqual(channel_route->source_bus(), bus_idx);
    XCTAssertEqual(channel_route->source_channel(), ch_idx);
    XCTAssertEqual(channel_route->destination_bus(), bus_idx);
    XCTAssertEqual(channel_route->destination_channel(), ch_idx);
}

- (void)testDefaultAudioChannelRoute
{
    const UInt32 bus_idx = 6;
    const UInt32 ch_count = 4;

    auto interleaved_format = yas::audio_format::create(44100.0, ch_count, yas::pcm_format::float32, true);

    XCTAssertThrows(yas::channel_route::default_channel_routes(bus_idx, interleaved_format));

    auto non_interleaved_format = yas::audio_format::create(44100.0, ch_count, yas::pcm_format::float32, false);

    auto channel_routes = yas::channel_route::default_channel_routes(bus_idx, non_interleaved_format);

    XCTAssertEqual(channel_routes.size(), ch_count);

    for (UInt32 ch_idx = 0; ch_idx < ch_count; ch_idx++) {
        auto &channel_route = channel_routes.at(ch_idx);
        XCTAssertEqual(channel_route->source_bus(), bus_idx);
        XCTAssertEqual(channel_route->source_channel(), ch_idx);
        XCTAssertEqual(channel_route->destination_bus(), bus_idx);
        XCTAssertEqual(channel_route->destination_channel(), ch_idx);
    }
}

@end
