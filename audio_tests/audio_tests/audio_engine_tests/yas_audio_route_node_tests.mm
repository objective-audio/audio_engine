//
//  yas_audio_route_node_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_route_node_tests : XCTestCase

@end

@implementation yas_audio_route_node_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_add_and_remove_route {
    audio::route_node route_node;

    XCTAssertEqual(route_node.routes().size(), 0);

    audio::route route{0, 1, 2, 3};
    route_node.add_route(route);

    XCTAssertEqual(route_node.routes().size(), 1);
    for (auto route_in_node : route_node.routes()) {
        XCTAssertEqual(route_in_node, route);
    }

    route_node.remove_route(route);

    XCTAssertEqual(route_node.routes().size(), 0);

    route_node.add_route(std::move(route));

    XCTAssertEqual(route_node.routes().size(), 1);

    route_node.clear_routes();

    XCTAssertEqual(route_node.routes().size(), 0);
}

- (void)test_replace_route {
    audio::route_node route_node;

    XCTAssertEqual(route_node.routes().size(), 0);

    route_node.add_route({0, 1, 2, 3});

    XCTAssertEqual(route_node.routes().size(), 1);

    std::set<audio::route> routes{{4, 5, 6, 7}, {8, 9, 10, 11}};
    route_node.set_routes(routes);

    XCTAssertEqual(route_node.routes().size(), 2);
    XCTAssertEqual(route_node.routes(), routes);

    route_node.clear_routes();

    XCTAssertEqual(route_node.routes().size(), 0);

    route_node.set_routes(std::move(routes));

    XCTAssertEqual(route_node.routes().size(), 2);
    XCTAssertNotEqual(route_node.routes(), routes);
}

- (void)test_render {
    audio::engine engine;

    auto format = audio::format(44100.0, 2);
    audio::offline_output_node output_node;
    audio::route_node route_node;
    audio::tap_node tap_node;

    engine.connect(route_node, output_node, format);
    engine.connect(tap_node, route_node, format);

    bool tap_node_called = false;
    tap_node.set_render_function(
        [&tap_node_called](const auto &, const auto, const auto &) { tap_node_called = true; });

    {
        XCTestExpectation *expectation = [self expectationWithDescription:@"first render"];

        XCTAssertTrue(engine.start_offline_render([](const auto &, const auto &, auto &out_stop) { out_stop = true; },
                                                  [expectation](const bool cancelled) { [expectation fulfill]; }));

        [self waitForExpectationsWithTimeout:0.5
                                     handler:^(NSError *error){

                                     }];
    }

    XCTAssertFalse(tap_node_called);

    route_node.add_route({0, 0, 0, 0});
    route_node.add_route({0, 1, 0, 1});

    tap_node_called = false;
    tap_node.set_render_function([&tap_node_called, self](const auto &buffer, const bool bus_idx, const auto &when) {
        tap_node_called = true;
        XCTAssertEqual(bus_idx, 0);
        test::fill_test_values_to_buffer(buffer);
    });

    {
        XCTestExpectation *expectation = [self expectationWithDescription:@"second render"];

        XCTAssertTrue(engine.start_offline_render(
            [self](audio::pcm_buffer &buffer, const audio::time &when, bool &out_stop) {
                out_stop = true;
                audio::frame_enumerator enumerator(buffer);
                auto pointer = enumerator.pointer();
                const uint32_t *frm_idx = enumerator.frame();
                const uint32_t *ch_idx = enumerator.channel();

                while (pointer->v) {
                    while (pointer->v) {
                        float test_value = (float)test::test_value(*frm_idx, 0, *ch_idx);
                        XCTAssertEqual(*pointer->f32, test_value);
                        yas_audio_frame_enumerator_move_channel(enumerator);
                    }
                    XCTAssertEqual(*ch_idx, 2);
                    yas_audio_frame_enumerator_move_frame(enumerator);
                }
            },
            [expectation](const bool cancelled) { [expectation fulfill]; }));

        [self waitForExpectationsWithTimeout:0.5
                                     handler:^(NSError *error){

                                     }];
    }

    XCTAssertTrue(tap_node_called);
}

- (void)test_render_many_source {
    const auto src_count = 2;

    audio::engine engine;

    auto dst_format = audio::format(44100.0, 2);
    auto src_format = audio::format(44100.0, 1);
    audio::offline_output_node output_node;
    audio::route_node route_node;

    engine.connect(route_node, output_node, dst_format);

    bool tap_node_calleds[src_count];
    for (auto &tap_node_called : tap_node_calleds) {
        tap_node_called = false;
    }

    std::vector<audio::tap_node> tap_nodes;
    for (uint32_t i = 0; i < src_count; ++i) {
        tap_nodes.push_back(audio::tap_node{});
        auto &tap_node = tap_nodes.at(i);

        engine.connect(tap_node, route_node, 0, i, src_format);

        auto &tap_node_called = tap_node_calleds[i];
        tap_node.set_render_function([&tap_node_called](const auto &buffer, const bool bus_idx, const auto &when) {
            tap_node_called = true;
            test::fill_test_values_to_buffer(buffer);
        });
    }

    route_node.add_route({0, 0, 0, 0});
    route_node.add_route({1, 0, 0, 1});

    XCTestExpectation *expectation = [self expectationWithDescription:@"render"];

    XCTAssertTrue(engine.start_offline_render(
        [self](audio::pcm_buffer &buffer, const audio::time &when, bool &out_stop) {
            out_stop = true;
            audio::frame_enumerator enumerator(buffer);
            auto pointer = enumerator.pointer();
            const uint32_t *frm_idx = enumerator.frame();
            const uint32_t *ch_idx = enumerator.channel();

            while (pointer->v) {
                while (pointer->v) {
                    float test_value = (float)test::test_value(*frm_idx, 0, 0);
                    XCTAssertEqual(*pointer->f32, test_value);
                    yas_audio_frame_enumerator_move_channel(enumerator);
                }
                XCTAssertEqual(*ch_idx, 2);
                yas_audio_frame_enumerator_move_frame(enumerator);
            }
        },
        [expectation](const bool cancelled) { [expectation fulfill]; }));

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    for (const auto &tap_node_called : tap_node_calleds) {
        XCTAssertTrue(tap_node_called);
    }
}

- (void)test_render_gappy_source {
    const auto src_count = 2;

    audio::engine engine;

    auto dst_format = audio::format(44100.0, 4);
    auto src_format = audio::format(44100.0, 2);
    audio::offline_output_node output_node;
    audio::route_node route_node;

    engine.connect(route_node, output_node, dst_format);

    bool tap_node_calleds[src_count];
    for (auto &tap_node_called : tap_node_calleds) {
        tap_node_called = false;
    }

    std::vector<audio::tap_node> tap_nodes;
    for (uint32_t i = 0; i < src_count; ++i) {
        tap_nodes.push_back(audio::tap_node{});
        auto &tap_node = tap_nodes.at(i);

        engine.connect(tap_node, route_node, 0, i, src_format);

        auto &tap_node_called = tap_node_calleds[i];
        tap_node.set_render_function([&tap_node_called](const auto &buffer, const bool bus_idx, const auto &when) {
            tap_node_called = true;
            test::fill_test_values_to_buffer(buffer);
        });
    }

    route_node.add_route({0, 0, 0, 0});
    route_node.add_route({1, 0, 0, 2});

    XCTestExpectation *expectation = [self expectationWithDescription:@"render"];

    XCTAssertTrue(engine.start_offline_render(
        [self](audio::pcm_buffer &buffer, const audio::time &when, bool &out_stop) {
            out_stop = true;
            audio::frame_enumerator enumerator(buffer);
            auto pointer = enumerator.pointer();
            const uint32_t *frm_idx = enumerator.frame();
            const uint32_t *ch_idx = enumerator.channel();

            while (pointer->v) {
                while (pointer->v) {
                    if (*ch_idx == 0 || *ch_idx == 2) {
                        float test_value = (float)test::test_value(*frm_idx, 0, 0);
                        XCTAssertEqual(*pointer->f32, test_value);
                    }
                    yas_audio_frame_enumerator_move_channel(enumerator);
                }
                XCTAssertEqual(*ch_idx, 4);
                yas_audio_frame_enumerator_move_frame(enumerator);
            }
        },
        [expectation](const bool cancelled) { [expectation fulfill]; }));

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    for (const auto &tap_node_called : tap_node_calleds) {
        XCTAssertTrue(tap_node_called);
    }
}

@end
