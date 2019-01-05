//
//  yas_audio_tap_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_tap_tests : XCTestCase

@end

@implementation yas_audio_tap_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_render_with_lambda {
    audio::engine::manager manager;
    manager.add_offline_output();

    audio::engine::offline_output &output = manager.offline_output();
    audio::engine::tap to_tap;
    audio::engine::tap from_tap;
    auto const format = audio::format({.sample_rate = 48000.0, .channel_count = 2});

    auto const to_connection = manager.connect(to_tap.node(), output.node(), format);
    auto const from_connection = manager.connect(from_tap.node(), to_tap.node(), format);

    XCTestExpectation *to_expectation = [self expectationWithDescription:@"to node"];
    XCTestExpectation *from_expectation = [self expectationWithDescription:@"from node"];
    XCTestExpectation *completion_expectation = [self expectationWithDescription:@"completion"];

    auto weak_to_tap = to_weak(to_tap);
    auto to_render_handler = [weak_to_tap, self, to_connection, from_connection, to_expectation](auto args) {
        auto &buffer = args.buffer;
        auto const &when = args.when;

        auto node = weak_to_tap.lock();
        XCTAssertTrue(node);
        if (node) {
            XCTAssertEqual(node.output_connections_on_render().size(), 1);
            XCTAssertEqual(to_connection, node.output_connection_on_render(0));
            XCTAssertFalse(node.output_connection_on_render(1));

            XCTAssertEqual(node.input_connections_on_render().size(), 1);
            XCTAssertEqual(from_connection, node.input_connection_on_render(0));
            XCTAssertFalse(node.input_connection_on_render(1));

            node.render_source({.buffer = buffer, .bus_idx = 0, .when = when});
        }

        [to_expectation fulfill];
    };

    to_tap.set_render_handler(std::move(to_render_handler));

    from_tap.set_render_handler([from_expectation](auto) { [from_expectation fulfill]; });

    XCTAssertTrue(manager.start_offline_render(
        [](auto args) { args.out_stop = true; },
        [completion_expectation](auto const cancelled) { [completion_expectation fulfill]; }));

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    [NSThread sleepForTimeInterval:1.0];
}

- (void)test_render_without_lambda {
    audio::engine::manager manager;
    manager.add_offline_output();

    audio::engine::offline_output &output = manager.offline_output();
    audio::engine::tap to_tap;
    audio::engine::tap from_tap;
    auto const format = audio::format({.sample_rate = 48000.0, .channel_count = 2});

    auto const to_connection = manager.connect(to_tap.node(), output.node(), format);
    auto const from_connection = manager.connect(from_tap.node(), to_tap.node(), format);

    XCTestExpectation *from_expectation = [self expectationWithDescription:@"from node"];

    from_tap.set_render_handler([from_expectation](auto) { [from_expectation fulfill]; });

    XCTAssertTrue(manager.start_offline_render([](auto args) { args.out_stop = true; }, nullptr));

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];
}

- (void)test_bus_count {
    audio::engine::tap tap;

    XCTAssertEqual(tap.node().input_bus_count(), 1);
    XCTAssertEqual(tap.node().output_bus_count(), 1);
}

@end
