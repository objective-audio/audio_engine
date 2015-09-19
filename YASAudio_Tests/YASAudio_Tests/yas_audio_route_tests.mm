//
//  yas_audio_route_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

@interface yas_audio_route_tests : XCTestCase

@end

@implementation yas_audio_route_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_create_route_full
{
    const UInt32 src_bus_idx = 0;
    const UInt32 src_ch_idx = 1;
    const UInt32 dst_bus_idx = 2;
    const UInt32 dst_ch_idx = 3;

    auto route = yas::audio_route(src_bus_idx, src_ch_idx, dst_bus_idx, dst_ch_idx);

    XCTAssertEqual(route.source.bus, src_bus_idx);
    XCTAssertEqual(route.source.channel, src_ch_idx);
    XCTAssertEqual(route.destination.bus, dst_bus_idx);
    XCTAssertEqual(route.destination.channel, dst_ch_idx);
}

- (void)test_create_route_common
{
    const UInt32 bus_idx = 4;
    const UInt32 ch_idx = 5;

    auto route = yas::audio_route(bus_idx, ch_idx);

    XCTAssertEqual(route.source.bus, bus_idx);
    XCTAssertEqual(route.source.channel, ch_idx);
    XCTAssertEqual(route.destination.bus, bus_idx);
    XCTAssertEqual(route.destination.channel, ch_idx);
}

- (void)test_create_route_points
{
    const yas::audio_route::point src_point(0, 1);
    const yas::audio_route::point dst_point(2, 3);

    auto route = yas::audio_route(src_point, dst_point);

    XCTAssertEqual(route.source.bus, 0);
    XCTAssertEqual(route.source.channel, 1);
    XCTAssertEqual(route.destination.bus, 2);
    XCTAssertEqual(route.destination.channel, 3);
}

- (void)test_channel_map_from_routes_normal
{
    yas::audio_route_set routes{{0, 0, 0, 0}, {0, 1, 0, 1}};

    auto result = yas::channel_map_from_routes(routes, 0, 2, 0, 2);
    XCTAssertTrue(result);

    const auto &map = result.value();
    XCTAssertEqual(map.at(0), 0);
    XCTAssertEqual(map.at(1), 1);
}

- (void)test_channel_map_from_routes_src_less_than_dst
{
    yas::audio_route_set routes{{0, 0, 0, 0}, {0, 1, 0, 1}};

    auto result = yas::channel_map_from_routes(routes, 0, 1, 0, 2);
    XCTAssertTrue(result);

    const auto &map = result.value();
    XCTAssertEqual(map.size(), 1);
    XCTAssertEqual(map.at(0), 0);
}

- (void)test_channel_map_from_routes_dst_less_than_src
{
    yas::audio_route_set routes{{0, 0, 0, 0}, {0, 1, 0, 1}};

    auto result = yas::channel_map_from_routes(routes, 0, 2, 0, 1);
    XCTAssertTrue(result);

    const auto &map = result.value();
    XCTAssertEqual(map.at(0), 0);
    XCTAssertEqual(map.at(1), -1);
}

- (void)test_channel_map_from_routes_filtered
{
    yas::audio_route_set routes{{0, 0, 0, 0}, {0, 1, 1, 1}, {1, 0, 0, 1}, {1, 1, 1, 0}};

    auto result_0_0 = yas::channel_map_from_routes(routes, 0, 2, 0, 2);
    XCTAssertTrue(result_0_0);
    if (result_0_0) {
        const auto &map = result_0_0.value();
        XCTAssertEqual(map.at(0), 0);
        XCTAssertEqual(map.at(1), -1);
    }

    auto result_0_1 = yas::channel_map_from_routes(routes, 0, 2, 1, 2);
    XCTAssertTrue(result_0_1);
    if (result_0_1) {
        const auto &map = result_0_1.value();
        XCTAssertEqual(map.at(0), -1);
        XCTAssertEqual(map.at(1), 1);
    }

    auto result_1_0 = yas::channel_map_from_routes(routes, 1, 2, 0, 2);
    XCTAssertTrue(result_1_0);
    if (result_1_0) {
        const auto &map = result_1_0.value();
        XCTAssertEqual(map.at(0), 1);
        XCTAssertEqual(map.at(1), -1);
    }

    auto result_1_1 = yas::channel_map_from_routes(routes, 1, 2, 1, 2);
    XCTAssertTrue(result_1_1);
    if (result_1_1) {
        const auto &map = result_1_1.value();
        XCTAssertEqual(map.at(0), -1);
        XCTAssertEqual(map.at(1), 0);
    }
}

@end
