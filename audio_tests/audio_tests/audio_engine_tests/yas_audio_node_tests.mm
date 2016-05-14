//
//  yas_audio_node_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_node_tests : XCTestCase

@end

@implementation yas_audio_node_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create_audio_node {
    test::audio_test_node node;

    XCTAssertEqual(node.input_bus_count(), 2);
    XCTAssertEqual(node.output_bus_count(), 1);

    XCTAssertEqual(node.manageable_node().input_connections().size(), 0);
    XCTAssertEqual(node.manageable_node().output_connections().size(), 0);
    XCTAssertEqual(*node.next_available_input_bus(), 0);
    XCTAssertEqual(*node.next_available_output_bus(), 0);
}

- (void)test_connection {
    test::audio_test_node source_node;
    test::audio_test_node destination_node;
    auto format = audio::format(44100.0, 2);
    auto source_bus_result = source_node.next_available_input_bus();
    auto destination_bus_result = destination_node.next_available_output_bus();

    XCTAssertTrue(source_bus_result);
    auto source_bus = *source_bus_result;
    XCTAssertEqual(source_bus, 0);

    XCTAssertTrue(destination_bus_result);
    auto destination_bus = *destination_bus_result;
    XCTAssertEqual(destination_bus, 0);

    if (auto connection = audio::connection::private_access::create(source_node, source_bus, destination_node,
                                                                    destination_bus, format)) {
        XCTAssertEqual(source_node.manageable_node().output_connections().size(), 1);
        XCTAssertEqual(destination_node.manageable_node().input_connections().size(), 1);
        XCTAssertEqual(source_node.manageable_node().output_connection(source_bus), connection);
        XCTAssertEqual(destination_node.manageable_node().input_connection(destination_bus), connection);
        XCTAssertEqual(source_node.output_format(source_bus), format);
        XCTAssertEqual(destination_node.input_format(destination_bus), format);

        XCTAssertFalse(source_node.output_format(source_bus + 1));
        XCTAssertFalse(destination_node.input_format(destination_bus + 1));

        XCTAssertFalse(source_node.next_available_output_bus());
        XCTAssertTrue(destination_node.next_available_input_bus());
        destination_bus_result = destination_node.next_available_input_bus();
        XCTAssertEqual(*destination_bus_result, 1);
    }

    source_bus_result = source_node.next_available_output_bus();
    destination_bus_result = destination_node.next_available_input_bus();
    XCTAssertEqual(*source_bus_result, 0);
    XCTAssertEqual(*destination_bus_result, 0);
}

- (void)test_reset {
    test::audio_test_node source_node;
    test::audio_test_node destination_node;
    auto format = audio::format(48000.0, 2);
    auto source_bus = *source_node.next_available_output_bus();
    auto destination_bus = *destination_node.next_available_input_bus();

    auto connection =
        audio::connection::private_access::create(source_node, source_bus, destination_node, destination_bus, format);

    XCTAssertEqual(source_node.manageable_node().output_connections().size(), 1);
    XCTAssertEqual(destination_node.manageable_node().input_connections().size(), 1);

    source_node.reset();
    XCTAssertEqual(source_node.manageable_node().output_connections().size(), 0);

    destination_node.reset();
    XCTAssertEqual(destination_node.manageable_node().input_connections().size(), 0);
}

- (void)test_render_time {
    auto node = audio::node::private_access::create();
    audio::time time(100, 48000.0);

    XCTestExpectation *render_expectation = [self expectationWithDescription:@"node render"];

    auto lambda = [self, node, time, render_expectation]() mutable {
        audio::pcm_buffer null_buffer{nullptr};
        node.render(null_buffer, 0, time);
        [render_expectation fulfill];
    };

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), lambda);

    [self waitForExpectationsWithTimeout:1.0
                                 handler:^(NSError *error){

                                 }];

    XCTAssertEqual(time, node.last_render_time());
}

- (void)test_set_engine {
    auto node = audio::node::private_access::create();
    audio::engine engine;

    XCTAssertFalse(node.engine());

    node.manageable_node().set_engine(engine);

    XCTAssertEqual(engine, node.engine());

    node.manageable_node().set_engine(audio::engine(nullptr));

    XCTAssertFalse(node.engine());
}

- (void)test_kernel {
    auto output_format = audio::format(48000.0, 2);
    auto input_format = audio::format(44100.0, 1);

    test::audio_test_node output_node;
    test::audio_test_node relay_node;

    auto output_connection = audio::connection::private_access::create(relay_node, 0, output_node, 0, output_format);

    std::vector<audio::connection> input_connections;
    input_connections.reserve(relay_node.input_bus_count());

    for (uint32_t i = 0; i < relay_node.input_bus_count(); ++i) {
        test::audio_test_node input_node;
        auto input_connection = audio::connection::private_access::create(input_node, 0, relay_node, i, input_format);
        input_node.manageable_node().add_connection(input_connection);
        input_connections.push_back(input_connection);
    }

    relay_node.manageable_node().update_kernel();

    XCTestExpectation *expectation = [self expectationWithDescription:@"kernel connections"];

    auto lambda = [self, expectation, relay_node, input_connections, output_connection]() {
        auto kernel = audio::node::private_access::kernel(relay_node);
        XCTAssertEqual(kernel.output_connections().size(), 1);
        XCTAssertEqual(kernel.input_connections().size(), 2);
        XCTAssertEqual(kernel.output_connection(0), output_connection);
        XCTAssertEqual(kernel.input_connection(0), input_connections.at(0));
        XCTAssertEqual(kernel.input_connection(1), input_connections.at(1));
        [expectation fulfill];
    };

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), lambda);

    [self waitForExpectationsWithTimeout:1.0
                                 handler:^(NSError *error){

                                 }];
}

- (void)test_available_bus {
    auto format = audio::format(48000.0, 2);
    test::audio_test_node source_node_0;
    test::audio_test_node source_node_1;
    test::audio_test_node destination_node;

    XCTAssertTrue(source_node_0.is_available_output_bus(0));
    XCTAssertFalse(source_node_0.is_available_output_bus(1));
    XCTAssertTrue(source_node_1.is_available_output_bus(0));
    XCTAssertTrue(destination_node.is_available_input_bus(0));
    XCTAssertTrue(destination_node.is_available_input_bus(1));
    XCTAssertFalse(destination_node.is_available_input_bus(2));

    auto connection_1 = audio::connection::private_access::create(source_node_1, 0, destination_node, 1, format);

    XCTAssertFalse(source_node_1.is_available_output_bus(0));
    XCTAssertTrue(destination_node.is_available_input_bus(0));
    XCTAssertFalse(destination_node.is_available_input_bus(1));

    auto connection_0 = audio::connection::private_access::create(source_node_0, 0, destination_node, 0, format);

    XCTAssertFalse(source_node_0.is_available_output_bus(0));
    XCTAssertFalse(destination_node.is_available_input_bus(0));
}

@end
