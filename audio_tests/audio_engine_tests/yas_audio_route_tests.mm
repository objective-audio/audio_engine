//
//  yas_audio_route_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_route_tests : XCTestCase

@end

@implementation yas_audio_route_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_add_and_remove_route {
    audio::engine::route engine_route;

    XCTAssertEqual(engine_route.routes().size(), 0);

    audio::route route{0, 1, 2, 3};
    engine_route.add_route(route);

    XCTAssertEqual(engine_route.routes().size(), 1);
    for (auto route_in_engine : engine_route.routes()) {
        XCTAssertEqual(route_in_engine, route);
    }

    engine_route.remove_route(route);

    XCTAssertEqual(engine_route.routes().size(), 0);

    engine_route.add_route(std::move(route));

    XCTAssertEqual(engine_route.routes().size(), 1);

    engine_route.clear_routes();

    XCTAssertEqual(engine_route.routes().size(), 0);
}

- (void)test_replace_route {
    audio::engine::route engine_route;

    XCTAssertEqual(engine_route.routes().size(), 0);

    engine_route.add_route({0, 1, 2, 3});

    XCTAssertEqual(engine_route.routes().size(), 1);

    std::set<audio::route> routes{{4, 5, 6, 7}, {8, 9, 10, 11}};
    engine_route.set_routes(routes);

    XCTAssertEqual(engine_route.routes().size(), 2);
    XCTAssertEqual(engine_route.routes(), routes);

    engine_route.clear_routes();

    XCTAssertEqual(engine_route.routes().size(), 0);

    engine_route.set_routes(std::move(routes));

    XCTAssertEqual(engine_route.routes().size(), 2);
    XCTAssertNotEqual(engine_route.routes(), routes);
}

- (void)test_render {
    audio::engine::manager manager;
    manager.add_offline_output();

    auto format = audio::format({.sample_rate = 44100.0, .channel_count = 2});
    audio::engine::offline_output &output = manager.offline_output();
    audio::engine::route engine_route;
    audio::engine::tap tap;

    audio::engine::node &route_node = engine_route.node();
    audio::engine::node &output_node = output.node();

    manager.connect(route_node, output_node, format);
    manager.connect(tap.node(), engine_route.node(), format);

    bool tap_called = false;
    tap.set_render_handler([&tap_called](auto) { tap_called = true; });

    {
        XCTestExpectation *expectation = [self expectationWithDescription:@"first render"];

        XCTAssertTrue(manager.start_offline_render([](auto args) { return audio::continuation::abort; },
                                                   [expectation](bool const cancelled) { [expectation fulfill]; }));

        [self waitForExpectationsWithTimeout:0.5
                                     handler:^(NSError *error){

                                     }];
    }

    XCTAssertFalse(tap_called);

    engine_route.add_route({0, 0, 0, 0});
    engine_route.add_route({0, 1, 0, 1});

    tap_called = false;
    tap.set_render_handler([&tap_called, self](auto args) {
        tap_called = true;
        XCTAssertEqual(args.bus_idx, 0);
        test::fill_test_values_to_buffer(args.buffer);
    });

    {
        XCTestExpectation *expectation = [self expectationWithDescription:@"second render"];

        XCTAssertTrue(manager.start_offline_render(
            [self](auto args) {
                auto each = audio::make_each_data<float>(args.buffer);
                while (yas_each_data_next(each)) {
                    float test_value = (float)test::test_value((uint32_t)each.frm_idx, 0, (uint32_t)each.ptr_idx);
                    XCTAssertEqual(yas_each_data_value(each), test_value);
                }
                return audio::continuation::abort;
            },
            [expectation](bool const cancelled) { [expectation fulfill]; }));

        [self waitForExpectationsWithTimeout:0.5
                                     handler:^(NSError *error){

                                     }];
    }

    XCTAssertTrue(tap_called);
}

- (void)test_render_many_source {
    auto const src_count = 2;

    audio::engine::manager manager;
    manager.add_offline_output();

    auto dst_format = audio::format({.sample_rate = 44100.0, .channel_count = 2});
    auto src_format = audio::format({.sample_rate = 44100.0, .channel_count = 1});
    audio::engine::offline_output &output = manager.offline_output();
    audio::engine::route engine_route;

    manager.connect(engine_route.node(), output.node(), dst_format);

    bool tap_calleds[src_count];
    for (auto &tap_called : tap_calleds) {
        tap_called = false;
    }

    std::vector<audio::engine::tap> taps;
    for (uint32_t i = 0; i < src_count; ++i) {
        taps.push_back(audio::engine::tap{});
        auto &tap = taps.at(i);

        manager.connect(tap.node(), engine_route.node(), 0, i, src_format);

        auto &tap_called = tap_calleds[i];
        tap.set_render_handler([&tap_called](auto args) {
            tap_called = true;
            test::fill_test_values_to_buffer(args.buffer);
        });
    }

    engine_route.add_route({0, 0, 0, 0});
    engine_route.add_route({1, 0, 0, 1});

    XCTestExpectation *expectation = [self expectationWithDescription:@"render"];

    XCTAssertTrue(manager.start_offline_render(
        [self](auto args) {
            auto each = audio::make_each_data<float>(args.buffer);
            while (yas_each_data_next(each)) {
                float test_value = (float)test::test_value((uint32_t)each.frm_idx, 0, 0);
                XCTAssertEqual(yas_each_data_value(each), test_value);
            }
            return audio::continuation::abort;
        },
        [expectation](bool const cancelled) { [expectation fulfill]; }));

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    for (auto const &tap_called : tap_calleds) {
        XCTAssertTrue(tap_called);
    }
}

- (void)test_render_gappy_source {
    auto const src_count = 2;

    audio::engine::manager manager;
    manager.add_offline_output();

    auto dst_format = audio::format({.sample_rate = 44100.0, .channel_count = 4});
    auto src_format = audio::format({.sample_rate = 44100.0, .channel_count = 2});
    audio::engine::offline_output &output = manager.offline_output();
    audio::engine::route engine_route;

    manager.connect(engine_route.node(), output.node(), dst_format);

    bool tap_calleds[src_count];
    for (auto &tap_called : tap_calleds) {
        tap_called = false;
    }

    std::vector<audio::engine::tap> taps;
    for (uint32_t i = 0; i < src_count; ++i) {
        taps.push_back(audio::engine::tap{});
        auto &tap = taps.at(i);

        manager.connect(tap.node(), engine_route.node(), 0, i, src_format);

        auto &tap_called = tap_calleds[i];
        tap.set_render_handler([&tap_called](auto args) {
            tap_called = true;
            test::fill_test_values_to_buffer(args.buffer);
        });
    }

    engine_route.add_route({0, 0, 0, 0});
    engine_route.add_route({1, 0, 0, 2});

    XCTestExpectation *expectation = [self expectationWithDescription:@"render"];

    XCTAssertTrue(manager.start_offline_render(
        [self](auto args) {
            auto each = audio::make_each_data<float>(args.buffer);
            while (yas_each_data_next(each)) {
                if (each.ptr_idx == 0 || each.ptr_idx == 2) {
                    float test_value = (float)test::test_value((uint32_t)each.frm_idx, 0, 0);
                    XCTAssertEqual(yas_each_data_value(each), test_value);
                }
            }
            return audio::continuation::abort;
        },
        [expectation](bool const cancelled) { [expectation fulfill]; }));

    [self waitForExpectationsWithTimeout:10.0
                                 handler:^(NSError *error){

                                 }];

    for (auto const &tap_called : tap_calleds) {
        XCTAssertTrue(tap_called);
    }
}

@end
