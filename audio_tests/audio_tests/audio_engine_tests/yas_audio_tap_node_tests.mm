//
//  yas_audio_tap_node_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_tap_node_tests : XCTestCase

@end

@implementation yas_audio_tap_node_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_render_with_lambda {
    audio::engine engine;
    engine.add_offline_output_node();

    audio::offline_output_node &output_node = engine.offline_output_node();
    audio::tap_node to_node;
    audio::tap_node from_node;
    auto const format = audio::format({.sample_rate = 48000.0, .channel_count = 2});

    auto const to_connection = engine.connect(to_node.node(), output_node.node(), format);
    auto const from_connection = engine.connect(from_node.node(), to_node.node(), format);

    XCTestExpectation *to_expectation = [self expectationWithDescription:@"to node"];
    XCTestExpectation *from_expectation = [self expectationWithDescription:@"from node"];
    XCTestExpectation *completion_expectation = [self expectationWithDescription:@"completion"];

    auto weak_to_node = to_weak(to_node);
    auto to_render_handler = [weak_to_node, self, to_connection, from_connection, to_expectation](
        auto &buffer, auto const &bus_idx, auto const &when) {
        auto node = weak_to_node.lock();
        XCTAssertTrue(node);
        if (node) {
            XCTAssertEqual(node.output_connections_on_render().size(), 1);
            XCTAssertEqual(to_connection, node.output_connection_on_render(0));
            XCTAssertFalse(node.output_connection_on_render(1));

            XCTAssertEqual(node.input_connections_on_render().size(), 1);
            XCTAssertEqual(from_connection, node.input_connection_on_render(0));
            XCTAssertFalse(node.input_connection_on_render(1));

            node.render_source(buffer, 0, when);
        }

        [to_expectation fulfill];
    };

    to_node.set_render_handler(std::move(to_render_handler));

    from_node.set_render_handler(
        [from_expectation](auto const &, auto const &, auto const &) { [from_expectation fulfill]; });

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
    engine.add_offline_output_node();

    audio::offline_output_node &output_node = engine.offline_output_node();
    audio::tap_node to_node;
    audio::tap_node from_node;
    auto const format = audio::format({.sample_rate = 48000.0, .channel_count = 2});

    auto const to_connection = engine.connect(to_node.node(), output_node.node(), format);
    auto const from_connection = engine.connect(from_node.node(), to_node.node(), format);

    XCTestExpectation *from_expectation = [self expectationWithDescription:@"from node"];

    from_node.set_render_handler(
        [from_expectation](auto const &, auto const &, auto const &) { [from_expectation fulfill]; });

    XCTAssertTrue(engine.start_offline_render([](auto args) { args.out_stop = true; }, nullptr));

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];
}

- (void)test_bus_count {
    audio::tap_node tap_node;

    XCTAssertEqual(tap_node.node().input_bus_count(), 1);
    XCTAssertEqual(tap_node.node().output_bus_count(), 1);
}

@end
