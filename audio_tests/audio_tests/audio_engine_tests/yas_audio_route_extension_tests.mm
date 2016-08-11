//
//  yas_audio_route_extension_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_route_extension_tests : XCTestCase

@end

@implementation yas_audio_route_extension_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_add_and_remove_route {
    audio::route_extension route_ext;

    XCTAssertEqual(route_ext.routes().size(), 0);

    audio::route route{0, 1, 2, 3};
    route_ext.add_route(route);

    XCTAssertEqual(route_ext.routes().size(), 1);
    for (auto route_in_ext : route_ext.routes()) {
        XCTAssertEqual(route_in_ext, route);
    }

    route_ext.remove_route(route);

    XCTAssertEqual(route_ext.routes().size(), 0);

    route_ext.add_route(std::move(route));

    XCTAssertEqual(route_ext.routes().size(), 1);

    route_ext.clear_routes();

    XCTAssertEqual(route_ext.routes().size(), 0);
}

- (void)test_replace_route {
    audio::route_extension route_ext;

    XCTAssertEqual(route_ext.routes().size(), 0);

    route_ext.add_route({0, 1, 2, 3});

    XCTAssertEqual(route_ext.routes().size(), 1);

    std::set<audio::route> routes{{4, 5, 6, 7}, {8, 9, 10, 11}};
    route_ext.set_routes(routes);

    XCTAssertEqual(route_ext.routes().size(), 2);
    XCTAssertEqual(route_ext.routes(), routes);

    route_ext.clear_routes();

    XCTAssertEqual(route_ext.routes().size(), 0);

    route_ext.set_routes(std::move(routes));

    XCTAssertEqual(route_ext.routes().size(), 2);
    XCTAssertNotEqual(route_ext.routes(), routes);
}

- (void)test_render {
    audio::engine engine;
    engine.add_offline_output_extension();

    auto format = audio::format({.sample_rate = 44100.0, .channel_count = 2});
    audio::offline_output_extension &output_ext = engine.offline_output_extension();
    audio::route_extension route_ext;
    audio::tap_extension tap_ext;

    engine.connect(route_ext.node(), output_ext.node(), format);
    engine.connect(tap_ext.node(), route_ext.node(), format);

    bool tap_ext_called = false;
    tap_ext.set_render_handler([&tap_ext_called](auto) { tap_ext_called = true; });

    {
        XCTestExpectation *expectation = [self expectationWithDescription:@"first render"];

        XCTAssertTrue(engine.start_offline_render([](auto args) { args.out_stop = true; },
                                                  [expectation](bool const cancelled) { [expectation fulfill]; }));

        [self waitForExpectationsWithTimeout:0.5
                                     handler:^(NSError *error){

                                     }];
    }

    XCTAssertFalse(tap_ext_called);

    route_ext.add_route({0, 0, 0, 0});
    route_ext.add_route({0, 1, 0, 1});

    tap_ext_called = false;
    tap_ext.set_render_handler([&tap_ext_called, self](auto args) {
        tap_ext_called = true;
        XCTAssertEqual(args.bus_idx, 0);
        test::fill_test_values_to_buffer(args.buffer);
    });

    {
        XCTestExpectation *expectation = [self expectationWithDescription:@"second render"];

        XCTAssertTrue(engine.start_offline_render(
            [self](auto args) {
                args.out_stop = true;
                audio::frame_enumerator enumerator(args.buffer);
                auto pointer = enumerator.pointer();
                uint32_t const *frm_idx = enumerator.frame();
                uint32_t const *ch_idx = enumerator.channel();

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
            [expectation](bool const cancelled) { [expectation fulfill]; }));

        [self waitForExpectationsWithTimeout:0.5
                                     handler:^(NSError *error){

                                     }];
    }

    XCTAssertTrue(tap_ext_called);
}

- (void)test_render_many_source {
    auto const src_count = 2;

    audio::engine engine;
    engine.add_offline_output_extension();

    auto dst_format = audio::format({.sample_rate = 44100.0, .channel_count = 2});
    auto src_format = audio::format({.sample_rate = 44100.0, .channel_count = 1});
    audio::offline_output_extension &output_ext = engine.offline_output_extension();
    audio::route_extension route_ext;

    engine.connect(route_ext.node(), output_ext.node(), dst_format);

    bool tap_ext_calleds[src_count];
    for (auto &tap_ext_called : tap_ext_calleds) {
        tap_ext_called = false;
    }

    std::vector<audio::tap_extension> tap_exts;
    for (uint32_t i = 0; i < src_count; ++i) {
        tap_exts.push_back(audio::tap_extension{});
        auto &tap_ext = tap_exts.at(i);

        engine.connect(tap_ext.node(), route_ext.node(), 0, i, src_format);

        auto &tap_ext_called = tap_ext_calleds[i];
        tap_ext.set_render_handler([&tap_ext_called](auto args) {
            tap_ext_called = true;
            test::fill_test_values_to_buffer(args.buffer);
        });
    }

    route_ext.add_route({0, 0, 0, 0});
    route_ext.add_route({1, 0, 0, 1});

    XCTestExpectation *expectation = [self expectationWithDescription:@"render"];

    XCTAssertTrue(engine.start_offline_render(
        [self](auto args) {
            args.out_stop = true;
            audio::frame_enumerator enumerator(args.buffer);
            auto pointer = enumerator.pointer();
            uint32_t const *frm_idx = enumerator.frame();
            uint32_t const *ch_idx = enumerator.channel();

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
        [expectation](bool const cancelled) { [expectation fulfill]; }));

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    for (auto const &tap_ext_called : tap_ext_calleds) {
        XCTAssertTrue(tap_ext_called);
    }
}

- (void)test_render_gappy_source {
    auto const src_count = 2;

    audio::engine engine;
    engine.add_offline_output_extension();

    auto dst_format = audio::format({.sample_rate = 44100.0, .channel_count = 4});
    auto src_format = audio::format({.sample_rate = 44100.0, .channel_count = 2});
    audio::offline_output_extension &output_ext = engine.offline_output_extension();
    audio::route_extension route_ext;

    engine.connect(route_ext.node(), output_ext.node(), dst_format);

    bool tap_ext_calleds[src_count];
    for (auto &tap_ext_called : tap_ext_calleds) {
        tap_ext_called = false;
    }

    std::vector<audio::tap_extension> tap_exts;
    for (uint32_t i = 0; i < src_count; ++i) {
        tap_exts.push_back(audio::tap_extension{});
        auto &tap_ext = tap_exts.at(i);

        engine.connect(tap_ext.node(), route_ext.node(), 0, i, src_format);

        auto &tap_ext_called = tap_ext_calleds[i];
        tap_ext.set_render_handler([&tap_ext_called](auto args) {
            tap_ext_called = true;
            test::fill_test_values_to_buffer(args.buffer);
        });
    }

    route_ext.add_route({0, 0, 0, 0});
    route_ext.add_route({1, 0, 0, 2});

    XCTestExpectation *expectation = [self expectationWithDescription:@"render"];

    XCTAssertTrue(engine.start_offline_render(
        [self](auto args) {
            args.out_stop = true;
            audio::frame_enumerator enumerator(args.buffer);
            auto pointer = enumerator.pointer();
            uint32_t const *const frm_idx = enumerator.frame();
            uint32_t const *const ch_idx = enumerator.channel();

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
        [expectation](bool const cancelled) { [expectation fulfill]; }));

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    for (auto const &tap_ext_called : tap_ext_calleds) {
        XCTAssertTrue(tap_ext_called);
    }
}

@end
