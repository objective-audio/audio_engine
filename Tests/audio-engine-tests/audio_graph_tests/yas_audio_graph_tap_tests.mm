//
//  yas_audio_tap_tests.m
//

#import "../yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_graph_tap_tests : XCTestCase

@end

@implementation yas_audio_graph_tap_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_render_with_lambda {
    auto graph = audio::graph::make_shared();

    auto to_tap = audio::graph_tap::make_shared();
    auto from_tap = audio::graph_tap::make_shared();
    auto const format = audio::format({.sample_rate = 48000.0, .channel_count = 2});

    auto const from_connection = graph->connect(from_tap->node, to_tap->node, format);

    XCTestExpectation *to_expectation = [self expectationWithDescription:@"to node"];
    XCTestExpectation *from_expectation = [self expectationWithDescription:@"from node"];
    XCTestExpectation *completion_expectation = [self expectationWithDescription:@"completion"];

    from_tap->set_render_handler([from_expectation](auto) { [from_expectation fulfill]; });

    auto const device = audio::offline_device::make_shared(
        format, [](audio::offline_render_args args) { return audio::continuation::abort; },
        [&completion_expectation](auto const cancelled) { [completion_expectation fulfill]; });

    auto const &offline_io = graph->add_io(device);

    auto const to_connection = graph->connect(to_tap->node, offline_io->output_node, format);

    auto to_render_handler = [self, to_connection = to_connection, from_connection = from_connection,
                              to_expectation](audio::node_render_args const &args) {
        auto &buffer = args.buffer;
        auto const &output_time = args.time;

        XCTAssertEqual(args.source_connections.size(), 1);

        auto const &pair = *args.source_connections.begin();
        XCTAssertEqual(pair.first, 0);

        audio::rendering_connection const &connection = pair.second;

        connection.render(buffer, output_time);

        [to_expectation fulfill];
    };

    to_tap->set_render_handler(std::move(to_render_handler));

    graph->start_render();

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    [NSThread sleepForTimeInterval:1.0];
}

- (void)test_render_without_lambda {
    auto graph = audio::graph::make_shared();

    auto to_tap = audio::graph_tap::make_shared();
    auto from_tap = audio::graph_tap::make_shared();
    auto const format = audio::format({.sample_rate = 48000.0, .channel_count = 2});

    graph->connect(from_tap->node, to_tap->node, format);

    XCTestExpectation *from_expectation = [self expectationWithDescription:@"from node"];

    from_tap->set_render_handler([&from_expectation](auto) { [from_expectation fulfill]; });

    XCTestExpectation *completion_expectation = [self expectationWithDescription:@"completion"];

    auto const device = audio::offline_device::make_shared(
        format, [](audio::offline_render_args args) { return audio::continuation::abort; },
        [&completion_expectation](bool const) { [completion_expectation fulfill]; });
    auto const &offline_io = graph->add_io(device);

    graph->connect(to_tap->node, offline_io->output_node, format);

    XCTAssertTrue(graph->start_render());

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];
}

- (void)test_bus_count {
    auto tap = audio::graph_tap::make_shared();

    XCTAssertEqual(tap->node->input_bus_count(), 1);
    XCTAssertEqual(tap->node->output_bus_count(), 1);
}

@end
