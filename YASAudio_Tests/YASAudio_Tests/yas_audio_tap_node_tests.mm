//
//  yas_audio_tap_node_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

@interface yas_audio_tap_node_tests : XCTestCase

@end

@implementation yas_audio_tap_node_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_render_with_lambda
{
    yas::audio_engine engine;

    yas::audio_offline_output_node output_node;
    yas::audio_tap_node to_node;
    yas::audio_tap_node from_node;
    const auto format = yas::audio_format(48000.0, 2);

    const auto to_connection = engine.connect(to_node, output_node, format);
    const auto from_connection = engine.connect(from_node, to_node, format);

    XCTestExpectation *to_expectation = [self expectationWithDescription:@"to node"];
    XCTestExpectation *from_expectation = [self expectationWithDescription:@"from node"];
    XCTestExpectation *completion_expectation = [self expectationWithDescription:@"completion"];

    auto weak_to_node = yas::to_weak(to_node);
    auto to_render_func = [weak_to_node, self, to_connection, from_connection, to_expectation](
        auto &buffer, const auto &bus_idx, const auto &when) {
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

    to_node.set_render_function(to_render_func);

    from_node.set_render_function(
        [from_expectation](const auto &, const auto &, const auto &) { [from_expectation fulfill]; });

    XCTAssertTrue(engine.start_offline_render(
        [](const auto &, const auto &, auto &stop) { stop = true; },
        [completion_expectation](const auto cancelled) { [completion_expectation fulfill]; }));

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    [NSThread sleepForTimeInterval:1.0];
}

- (void)test_render_without_lambda
{
    yas::audio_engine engine;

    yas::audio_offline_output_node output_node;
    yas::audio_tap_node to_node;
    yas::audio_tap_node from_node;
    const auto format = yas::audio_format(48000.0, 2);

    const auto to_connection = engine.connect(to_node, output_node, format);
    const auto from_connection = engine.connect(from_node, to_node, format);

    XCTestExpectation *from_expectation = [self expectationWithDescription:@"from node"];

    from_node.set_render_function(
        [from_expectation](const auto &, const auto &, const auto &) { [from_expectation fulfill]; });

    XCTAssertTrue(engine.start_offline_render([](const auto &, const auto &, auto &stop) { stop = true; }, nullptr));

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];
}

- (void)test_bus_count
{
    yas::audio_tap_node node;

    XCTAssertEqual(node.input_bus_count(), 1);
    XCTAssertEqual(node.output_bus_count(), 1);
}

@end
