//
//  yas_audio_route_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_graph_route_tests : XCTestCase

@end

@implementation yas_audio_graph_route_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_add_and_remove_route {
    auto graph_route = audio::graph_route::make_shared();

    XCTAssertEqual(graph_route->routes().size(), 0);

    audio::route route{0, 1, 2, 3};
    graph_route->add_route(route);

    XCTAssertEqual(graph_route->routes().size(), 1);
    for (auto route_in_graph : graph_route->routes()) {
        XCTAssertEqual(route_in_graph, route);
    }

    graph_route->remove_route(route);

    XCTAssertEqual(graph_route->routes().size(), 0);

    graph_route->add_route(std::move(route));

    XCTAssertEqual(graph_route->routes().size(), 1);

    graph_route->clear_routes();

    XCTAssertEqual(graph_route->routes().size(), 0);
}

- (void)test_replace_route {
    auto graph_route = audio::graph_route::make_shared();

    XCTAssertEqual(graph_route->routes().size(), 0);

    graph_route->add_route({0, 1, 2, 3});

    XCTAssertEqual(graph_route->routes().size(), 1);

    std::set<audio::route> routes{{4, 5, 6, 7}, {8, 9, 10, 11}};
    graph_route->set_routes(routes);

    XCTAssertEqual(graph_route->routes().size(), 2);
    XCTAssertEqual(graph_route->routes(), routes);

    graph_route->clear_routes();

    XCTAssertEqual(graph_route->routes().size(), 0);

    graph_route->set_routes(std::move(routes));

    XCTAssertEqual(graph_route->routes().size(), 2);
    XCTAssertNotEqual(graph_route->routes(), routes);
}

- (void)test_render {
    auto graph = audio::graph::make_shared();

    auto format = audio::format({.sample_rate = 44100.0, .channel_count = 2});
    auto graph_route = audio::graph_route::make_shared();
    auto tap = audio::graph_tap::make_shared();

    bool tap_called = false;
    tap->set_render_handler([&tap_called](auto) { tap_called = true; });

    graph->connect(tap->node(), graph_route->node(), format);

    {
        XCTestExpectation *expectation = [self expectationWithDescription:@"first render"];

        auto device =
            audio::offline_device::make_shared(format, [](auto args) { return audio::continuation::abort; },
                                               [&expectation](bool const cancelled) { [expectation fulfill]; });

        auto const &offline_io = graph->add_io(device);

        graph->connect(graph_route->node(), offline_io->node(), format);

        auto result = graph->start_render();

        XCTAssertTrue(result);

        [self waitForExpectationsWithTimeout:0.5
                                     handler:^(NSError *error){

                                     }];
    }

    XCTAssertFalse(tap_called);

    graph->remove_io();

    graph_route->add_route({0, 0, 0, 0});
    graph_route->add_route({0, 1, 0, 1});

    tap_called = false;
    tap->set_render_handler([&tap_called, self](auto args) {
        tap_called = true;
        XCTAssertEqual(args.bus_idx, 0);
        test::fill_test_values_to_buffer(*args.buffer);
    });

    {
        XCTestExpectation *expectation = [self expectationWithDescription:@"second render"];

        auto const device = audio::offline_device::make_shared(
            format,
            [self](auto args) {
                auto each = audio::make_each_data<float>(*args.buffer);
                while (yas_each_data_next(each)) {
                    float test_value = (float)test::test_value((uint32_t)each.frm_idx, 0, (uint32_t)each.ptr_idx);
                    XCTAssertEqual(yas_each_data_value(each), test_value);
                }
                return audio::continuation::abort;
            },
            [&expectation](bool const cancelled) { [expectation fulfill]; });

        auto const &offline_io = graph->add_io(device);

        graph->connect(graph_route->node(), offline_io->node(), format);

        auto result = graph->start_render();

        XCTAssertTrue(result);

        [self waitForExpectationsWithTimeout:0.5
                                     handler:^(NSError *error){

                                     }];
    }

    XCTAssertTrue(tap_called);
}

- (void)test_render_many_source {
    auto const src_count = 2;

    auto graph = audio::graph::make_shared();

    auto dst_format = audio::format({.sample_rate = 44100.0, .channel_count = 2});
    auto src_format = audio::format({.sample_rate = 44100.0, .channel_count = 1});
    auto graph_route = audio::graph_route::make_shared();

    bool tap_calleds[src_count];
    for (auto &tap_called : tap_calleds) {
        tap_called = false;
    }

    std::vector<audio::graph_tap_ptr> taps;
    for (uint32_t i = 0; i < src_count; ++i) {
        taps.push_back(audio::graph_tap::make_shared());
        auto &tap = taps.at(i);

        graph->connect(tap->node(), graph_route->node(), 0, i, src_format);

        auto &tap_called = tap_calleds[i];
        tap->set_render_handler([&tap_called](auto args) {
            tap_called = true;
            test::fill_test_values_to_buffer(*args.buffer);
        });
    }

    graph_route->add_route({0, 0, 0, 0});
    graph_route->add_route({1, 0, 0, 1});

    XCTestExpectation *expectation = [self expectationWithDescription:@"render"];

    auto const device = audio::offline_device::make_shared(
        dst_format,
        [self](auto args) {
            auto each = audio::make_each_data<float>(*args.buffer);
            while (yas_each_data_next(each)) {
                float test_value = (float)test::test_value((uint32_t)each.frm_idx, 0, 0);
                XCTAssertEqual(yas_each_data_value(each), test_value);
            }
            return audio::continuation::abort;
        },
        [&expectation](bool const cancelled) { [expectation fulfill]; });

    auto const &offline_io = graph->add_io(device);

    graph->connect(graph_route->node(), offline_io->node(), dst_format);

    graph->start_render();

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    for (auto const &tap_called : tap_calleds) {
        XCTAssertTrue(tap_called);
    }
}

- (void)test_render_gappy_source {
    auto const src_count = 2;

    auto graph = audio::graph::make_shared();

    auto dst_format = audio::format({.sample_rate = 44100.0, .channel_count = 4});
    auto src_format = audio::format({.sample_rate = 44100.0, .channel_count = 2});
    auto graph_route = audio::graph_route::make_shared();

    bool tap_calleds[src_count];
    for (auto &tap_called : tap_calleds) {
        tap_called = false;
    }

    std::vector<audio::graph_tap_ptr> taps;
    for (uint32_t i = 0; i < src_count; ++i) {
        taps.push_back(audio::graph_tap::make_shared());
        auto &tap = taps.at(i);

        graph->connect(tap->node(), graph_route->node(), 0, i, src_format);

        auto &tap_called = tap_calleds[i];
        tap->set_render_handler([&tap_called](auto args) {
            tap_called = true;
            test::fill_test_values_to_buffer(*args.buffer);
        });
    }

    graph_route->add_route({0, 0, 0, 0});
    graph_route->add_route({1, 0, 0, 2});

    XCTestExpectation *expectation = [self expectationWithDescription:@"render"];

    auto const device = audio::offline_device::make_shared(
        dst_format,
        [self](auto args) {
            auto each = audio::make_each_data<float>(*args.buffer);
            while (yas_each_data_next(each)) {
                if (each.ptr_idx == 0 || each.ptr_idx == 2) {
                    float test_value = (float)test::test_value((uint32_t)each.frm_idx, 0, 0);
                    XCTAssertEqual(yas_each_data_value(each), test_value);
                }
            }
            return audio::continuation::abort;
        },
        [&expectation](bool const cancelled) { [expectation fulfill]; });

    auto const &offline_io = graph->add_io(device);

    graph->connect(graph_route->node(), offline_io->node(), dst_format);

    graph->start_render();

    [self waitForExpectationsWithTimeout:10.0
                                 handler:^(NSError *error){

                                 }];

    for (auto const &tap_called : tap_calleds) {
        XCTAssertTrue(tap_called);
    }
}

@end
