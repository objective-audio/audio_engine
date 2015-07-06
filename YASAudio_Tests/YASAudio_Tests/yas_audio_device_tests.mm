//
//  yas_audio_device_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "yas_audio_channel_route.h"
#import "yas_audio_format.h"

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
    const UInt32 bus = 4;
    const UInt32 channel = 5;

    auto channel_route = yas::channel_route::create(bus, channel);

    XCTAssertEqual(channel_route->source_bus(), bus);
    XCTAssertEqual(channel_route->source_channel(), channel);
    XCTAssertEqual(channel_route->destination_bus(), bus);
    XCTAssertEqual(channel_route->destination_channel(), channel);
}

- (void)testDefaultAudioChannelRoute
{
    const UInt32 bus = 6;
    const UInt32 channels = 4;

    auto interleaved_format = yas::audio_format::create(44100.0, channels, yas::pcm_format::float32, true);

    XCTAssertThrows(yas::channel_route::default_channel_routes(bus, interleaved_format));

    auto non_interleaved_format = yas::audio_format::create(44100.0, channels, yas::pcm_format::float32, false);

    auto channel_routes = yas::channel_route::default_channel_routes(bus, non_interleaved_format);

    XCTAssertEqual(channel_routes.size(), channels);

    for (UInt32 ch = 0; ch < channels; ch++) {
        auto &channel_route = channel_routes.at(ch);
        XCTAssertEqual(channel_route->source_bus(), bus);
        XCTAssertEqual(channel_route->source_channel(), ch);
        XCTAssertEqual(channel_route->destination_bus(), bus);
        XCTAssertEqual(channel_route->destination_channel(), ch);
    }
}

@end
