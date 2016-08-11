//
//  yas_audio_tap_extension_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_tap_extension_tests : XCTestCase

@end

@implementation yas_audio_tap_extension_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_render_with_lambda {
    audio::engine engine;
    engine.add_offline_output_extension();

    audio::offline_output_extension &output_ext = engine.offline_output_extension();
    audio::tap_extension to_ext;
    audio::tap_extension from_ext;
    auto const format = audio::format({.sample_rate = 48000.0, .channel_count = 2});

    auto const to_connection = engine.connect(to_ext.node(), output_ext.node(), format);
    auto const from_connection = engine.connect(from_ext.node(), to_ext.node(), format);

    XCTestExpectation *to_expectation = [self expectationWithDescription:@"to node"];
    XCTestExpectation *from_expectation = [self expectationWithDescription:@"from node"];
    XCTestExpectation *completion_expectation = [self expectationWithDescription:@"completion"];

    auto weak_to_ext = to_weak(to_ext);
    auto to_render_handler = [weak_to_ext, self, to_connection, from_connection, to_expectation](auto args) {
        auto &buffer = args.buffer;
        auto const &when = args.when;

        auto to_ext = weak_to_ext.lock();
        XCTAssertTrue(to_ext);
        if (to_ext) {
            XCTAssertEqual(to_ext.output_connections_on_render().size(), 1);
            XCTAssertEqual(to_connection, to_ext.output_connection_on_render(0));
            XCTAssertFalse(to_ext.output_connection_on_render(1));

            XCTAssertEqual(to_ext.input_connections_on_render().size(), 1);
            XCTAssertEqual(from_connection, to_ext.input_connection_on_render(0));
            XCTAssertFalse(to_ext.input_connection_on_render(1));

            to_ext.render_source({.buffer = buffer, .bus_idx = 0, .when = when});
        }

        [to_expectation fulfill];
    };

    to_ext.set_render_handler(std::move(to_render_handler));

    from_ext.set_render_handler([from_expectation](auto) { [from_expectation fulfill]; });

    XCTAssertTrue(engine.start_offline_render(
        [](auto args) { args.out_stop = true; },
        [completion_expectation](auto const cancelled) { [completion_expectation fulfill]; }));

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    [NSThread sleepForTimeInterval:1.0];
}

- (void)test_render_without_lambda {
    audio::engine engine;
    engine.add_offline_output_extension();

    audio::offline_output_extension &output_ext = engine.offline_output_extension();
    audio::tap_extension to_ext;
    audio::tap_extension from_ext;
    auto const format = audio::format({.sample_rate = 48000.0, .channel_count = 2});

    auto const to_connection = engine.connect(to_ext.node(), output_ext.node(), format);
    auto const from_connection = engine.connect(from_ext.node(), to_ext.node(), format);

    XCTestExpectation *from_expectation = [self expectationWithDescription:@"from node"];

    from_ext.set_render_handler([from_expectation](auto) { [from_expectation fulfill]; });

    XCTAssertTrue(engine.start_offline_render([](auto args) { args.out_stop = true; }, nullptr));

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];
}

- (void)test_bus_count {
    audio::tap_extension tap_ext;

    XCTAssertEqual(tap_ext.node().input_bus_count(), 1);
    XCTAssertEqual(tap_ext.node().output_bus_count(), 1);
}

@end
