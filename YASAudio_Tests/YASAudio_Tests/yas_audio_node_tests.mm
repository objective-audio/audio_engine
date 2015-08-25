//
//  yas_audio_node_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "yas_audio.h"
#import "yas_audio_test_utils.h"

@interface yas_audio_node_tests : XCTestCase

@end

@implementation yas_audio_node_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_create_audio_node
{
    auto node = yas::test::audio_test_node::create();

    XCTAssertEqual(node->input_bus_count(), 2);
    XCTAssertEqual(node->output_bus_count(), 1);

    XCTAssertEqual(yas::audio_node::private_access::input_connections(node).size(), 0);
    XCTAssertEqual(yas::audio_node::private_access::output_connections(node).size(), 0);
    XCTAssertEqual(*node->next_available_input_bus(), 0);
    XCTAssertEqual(*node->next_available_output_bus(), 0);
}

- (void)test_connection
{
    auto source_node = yas::test::audio_test_node::create();
    auto destination_node = yas::test::audio_test_node::create();
    auto format = yas::audio_format::create(44100.0, 2);
    auto source_bus_result = source_node->next_available_input_bus();
    auto destination_bus_result = destination_node->next_available_output_bus();

    XCTAssertTrue(source_bus_result);
    auto source_bus = *source_bus_result;
    XCTAssertEqual(source_bus, 0);

    XCTAssertTrue(destination_bus_result);
    auto destination_bus = *destination_bus_result;
    XCTAssertEqual(destination_bus, 0);

    if (auto connection = yas::audio_connection::private_access::create(source_node, source_bus, destination_node,
                                                                        destination_bus, format)) {
        XCTAssertEqual(yas::audio_node::private_access::output_connections(source_node).size(), 1);
        XCTAssertEqual(yas::audio_node::private_access::input_connections(destination_node).size(), 1);
        XCTAssertEqual(yas::audio_node::private_access::output_connection(source_node, source_bus), connection);
        XCTAssertEqual(yas::audio_node::private_access::input_connection(destination_node, destination_bus),
                       connection);
        XCTAssertEqual(source_node->output_format(source_bus), format);
        XCTAssertEqual(destination_node->input_format(destination_bus), format);

        XCTAssertFalse(source_node->next_available_output_bus());
        XCTAssertTrue(destination_node->next_available_input_bus());
        destination_bus_result = destination_node->next_available_input_bus();
        XCTAssertEqual(*destination_bus_result, 1);
    }

    source_bus_result = source_node->next_available_output_bus();
    destination_bus_result = destination_node->next_available_input_bus();
    XCTAssertEqual(*source_bus_result, 0);
    XCTAssertEqual(*destination_bus_result, 0);
}

- (void)test_reset
{
    auto source_node = yas::test::audio_test_node::create();
    auto destination_node = yas::test::audio_test_node::create();
    auto format = yas::audio_format::create(48000.0, 2);
    auto source_bus = *source_node->next_available_output_bus();
    auto destination_bus = *destination_node->next_available_input_bus();

    auto connection = yas::audio_connection::private_access::create(source_node, source_bus, destination_node,
                                                                    destination_bus, format);

    XCTAssertEqual(yas::audio_node::private_access::output_connections(source_node).size(), 1);
    XCTAssertEqual(yas::audio_node::private_access::input_connections(destination_node).size(), 1);

    source_node->reset();
    XCTAssertEqual(yas::audio_node::private_access::output_connections(source_node).size(), 0);

    destination_node->reset();
    XCTAssertEqual(yas::audio_node::private_access::input_connections(destination_node).size(), 0);
}

- (void)test_render_time
{
    auto node = yas::audio_node::private_access::create();
    auto time = std::make_shared<yas::audio_time>(100, 48000.0);

    XCTestExpectation *render_expectation = [self expectationWithDescription:@"node render"];

    auto lambda = [self, node, time, render_expectation]() {
        node->render(nil, 0, time);
        [render_expectation fulfill];
    };

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), lambda);

    [self waitForExpectationsWithTimeout:1.0
                                 handler:^(NSError *error){

                                 }];

    XCTAssertEqual(time, node->last_render_time());
}

- (void)test_set_engine
{
    auto node = yas::audio_node::private_access::create();
    auto engine = yas::audio_engine::create();

    XCTAssertEqual(node->engine(), nullptr);

    yas::audio_node::private_access::set_engine(node, engine);

    XCTAssertEqual(engine, yas::audio_node::private_access::engine(node));

    yas::audio_node::private_access::set_engine(node, nil);

    XCTAssertEqual(node->engine(), nullptr);
}

- (void)test_node_core
{
    auto output_format = yas::audio_format::create(48000.0, 2);
    auto input_format = yas::audio_format::create(44100.0, 1);

    auto output_node = yas::test::audio_test_node::create();
    auto relay_node = yas::test::audio_test_node::create();

    auto output_connection =
        yas::audio_connection::private_access::create(relay_node, 0, output_node, 0, output_format);

    std::vector<yas::audio_connection_sptr> input_connections;
    input_connections.reserve(relay_node->input_bus_count());

    for (uint32_t i = 0; i < relay_node->input_bus_count(); ++i) {
        auto input_node = yas::test::audio_test_node::create();
        auto input_connection =
            yas::audio_connection::private_access::create(input_node, 0, relay_node, i, input_format);
        yas::audio_node::private_access::add_connection(input_node, input_connection);
        input_connections.push_back(input_connection);
    }

    yas::audio_node::private_access::update_node_core(relay_node);

    XCTestExpectation *expectation = [self expectationWithDescription:@"node_core connections"];

    auto lambda = [self, expectation, relay_node, input_connections, output_connection]() {
        auto node_core = yas::audio_node::private_access::node_core(relay_node);
        XCTAssertEqual(node_core->output_connections.size(), 1);
        XCTAssertEqual(node_core->input_connections.size(), 2);
        XCTAssertEqual(node_core->output_connection(0), output_connection);
        XCTAssertEqual(node_core->input_connection(0), input_connections.at(0));
        XCTAssertEqual(node_core->input_connection(1), input_connections.at(1));
        [expectation fulfill];
    };

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), lambda);

    [self waitForExpectationsWithTimeout:1.0
                                 handler:^(NSError *error){

                                 }];
}

- (void)test_available_bus
{
    auto format = yas::audio_format::create(48000.0, 2);
    auto source_node_0 = yas::test::audio_test_node::create();
    auto source_node_1 = yas::test::audio_test_node::create();
    auto destination_node = yas::test::audio_test_node::create();

    XCTAssertTrue(source_node_0->is_available_output_bus(0));
    XCTAssertFalse(source_node_0->is_available_output_bus(1));
    XCTAssertTrue(source_node_1->is_available_output_bus(0));
    XCTAssertTrue(destination_node->is_available_input_bus(0));
    XCTAssertTrue(destination_node->is_available_input_bus(1));
    XCTAssertFalse(destination_node->is_available_input_bus(2));

    auto connection_1 = yas::audio_connection::private_access::create(source_node_1, 0, destination_node, 1, format);

    XCTAssertFalse(source_node_1->is_available_output_bus(0));
    XCTAssertTrue(destination_node->is_available_input_bus(0));
    XCTAssertFalse(destination_node->is_available_input_bus(1));

    auto connection_0 = yas::audio_connection::private_access::create(source_node_0, 0, destination_node, 0, format);

    XCTAssertFalse(source_node_0->is_available_output_bus(0));
    XCTAssertFalse(destination_node->is_available_input_bus(0));
}

@end
