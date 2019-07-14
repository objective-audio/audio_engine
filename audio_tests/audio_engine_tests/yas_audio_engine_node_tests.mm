//
//  yas_audio_engine_node_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_engine_node_tests : XCTestCase

@end

@implementation yas_audio_engine_node_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create_audio_node {
    test::audio_test_node_object obj;

    XCTAssertEqual(obj.node().input_bus_count(), 2);
    XCTAssertEqual(obj.node().output_bus_count(), 1);

    XCTAssertTrue(obj.node().manageable());
    XCTAssertTrue(obj.node().connectable());

    XCTAssertEqual(obj.node().manageable().input_connections().size(), 0);
    XCTAssertEqual(obj.node().manageable().output_connections().size(), 0);
    XCTAssertEqual(*obj.node().next_available_input_bus(), 0);
    XCTAssertEqual(*obj.node().next_available_output_bus(), 0);
}

- (void)test_create_null {
    audio::engine::node node{nullptr};

    XCTAssertFalse(node);
}

- (void)test_create_kernel {
    audio::engine::kernel kernel;

    XCTAssertEqual(kernel.input_connections().size(), 0);
    XCTAssertEqual(kernel.output_connections().size(), 0);
}

- (void)test_connection {
    test::audio_test_node_object src_obj;
    test::audio_test_node_object dst_obj;
    auto format = audio::format({.sample_rate = 44100.0, .channel_count = 2});
    auto source_bus_result = src_obj.node().next_available_input_bus();
    auto destination_bus_result = dst_obj.node().next_available_output_bus();

    XCTAssertTrue(source_bus_result);
    auto source_bus = *source_bus_result;
    XCTAssertEqual(source_bus, 0);

    XCTAssertTrue(destination_bus_result);
    auto destination_bus = *destination_bus_result;
    XCTAssertEqual(destination_bus, 0);

    if (auto connection = test::connection(src_obj.node(), source_bus, dst_obj.node(), destination_bus, format)) {
        XCTAssertEqual(src_obj.node().manageable().output_connections().size(), 1);
        XCTAssertEqual(dst_obj.node().manageable().input_connections().size(), 1);
        XCTAssertEqual(src_obj.node().manageable().output_connection(source_bus), connection);
        XCTAssertEqual(dst_obj.node().manageable().input_connection(destination_bus), connection);
        XCTAssertEqual(src_obj.node().output_format(source_bus), format);
        XCTAssertEqual(dst_obj.node().input_format(destination_bus), format);

        XCTAssertFalse(src_obj.node().output_format(source_bus + 1));
        XCTAssertFalse(dst_obj.node().input_format(destination_bus + 1));

        XCTAssertFalse(src_obj.node().next_available_output_bus());
        XCTAssertTrue(dst_obj.node().next_available_input_bus());
        destination_bus_result = dst_obj.node().next_available_input_bus();
        XCTAssertEqual(*destination_bus_result, 1);
    }

    source_bus_result = src_obj.node().next_available_output_bus();
    destination_bus_result = dst_obj.node().next_available_input_bus();
    XCTAssertEqual(*source_bus_result, 0);
    XCTAssertEqual(*destination_bus_result, 0);
}

- (void)test_reset {
    test::audio_test_node_object src_obj;
    test::audio_test_node_object dst_obj;
    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    auto source_bus = *src_obj.node().next_available_output_bus();
    auto destination_bus = *dst_obj.node().next_available_input_bus();

    auto connection = test::connection(src_obj.node(), source_bus, dst_obj.node(), destination_bus, format);

    XCTAssertEqual(src_obj.node().manageable().output_connections().size(), 1);
    XCTAssertEqual(dst_obj.node().manageable().input_connections().size(), 1);

    src_obj.node().reset();
    XCTAssertEqual(src_obj.node().manageable().output_connections().size(), 0);

    dst_obj.node().reset();
    XCTAssertEqual(dst_obj.node().manageable().input_connections().size(), 0);
}

- (void)test_render_time {
    auto node = test::make_node();
    audio::time time(100, 48000.0);

    XCTestExpectation *render_expectation = [self expectationWithDescription:@"node render"];

    auto lambda = [self, node, time, render_expectation]() mutable {
        std::shared_ptr<audio::pcm_buffer> null_buffer{nullptr};
        node.render({.buffer = *null_buffer, .bus_idx = 0, .when = time});
        [render_expectation fulfill];
    };

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), lambda);

    [self waitForExpectationsWithTimeout:1.0
                                 handler:^(NSError *error){

                                 }];

    XCTAssertEqual(time, node.last_render_time());
}

- (void)test_set_manager {
    auto node = test::make_node();
    audio::engine::manager manager;

    XCTAssertFalse(node.manager());

    node.manageable().set_manager(manager);

    XCTAssertEqual(manager, node.manager());

    node.manageable().set_manager(audio::engine::manager{nullptr});

    XCTAssertFalse(node.manager());
}

- (void)test_kernel {
    auto output_format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    auto input_format = audio::format({.sample_rate = 44100.0, .channel_count = 1});

    test::audio_test_node_object output_obj;
    test::audio_test_node_object relay_obj;

    auto output_connection = test::connection(relay_obj.node(), 0, output_obj.node(), 0, output_format);

    std::vector<audio::engine::connection> input_connections;
    input_connections.reserve(relay_obj.node().input_bus_count());

    for (uint32_t i = 0; i < relay_obj.node().input_bus_count(); ++i) {
        test::audio_test_node_object input_obj;
        auto input_connection = test::connection(input_obj.node(), 0, relay_obj.node(), i, input_format);
        input_obj.node().connectable().add_connection(input_connection);
        input_connections.push_back(input_connection);
    }

    relay_obj.node().manageable().update_kernel();

    XCTestExpectation *expectation = [self expectationWithDescription:@"kernel connections"];

    auto lambda = [self, expectation, relay_obj = relay_obj.node(), input_connections, output_connection]() {
        auto kernel = relay_obj.kernel();
        XCTAssertEqual(kernel->output_connections().size(), 1);
        XCTAssertEqual(kernel->input_connections().size(), 2);
        XCTAssertEqual(kernel->output_connection(0), output_connection);
        XCTAssertEqual(kernel->input_connection(0), input_connections.at(0));
        XCTAssertEqual(kernel->input_connection(1), input_connections.at(1));
        [expectation fulfill];
    };

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), lambda);

    [self waitForExpectationsWithTimeout:1.0
                                 handler:^(NSError *error){

                                 }];
}

- (void)test_available_bus {
    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::audio_test_node_object src_obj_0;
    test::audio_test_node_object src_obj_1;
    test::audio_test_node_object dst_obj;

    XCTAssertTrue(src_obj_0.node().is_available_output_bus(0));
    XCTAssertFalse(src_obj_0.node().is_available_output_bus(1));
    XCTAssertTrue(src_obj_1.node().is_available_output_bus(0));
    XCTAssertTrue(dst_obj.node().is_available_input_bus(0));
    XCTAssertTrue(dst_obj.node().is_available_input_bus(1));
    XCTAssertFalse(dst_obj.node().is_available_input_bus(2));

    auto connection_1 = test::connection(src_obj_1.node(), 0, dst_obj.node(), 1, format);

    XCTAssertFalse(src_obj_1.node().is_available_output_bus(0));
    XCTAssertTrue(dst_obj.node().is_available_input_bus(0));
    XCTAssertFalse(dst_obj.node().is_available_input_bus(1));

    auto connection_0 = test::connection(src_obj_0.node(), 0, dst_obj.node(), 0, format);

    XCTAssertFalse(src_obj_0.node().is_available_output_bus(0));
    XCTAssertFalse(dst_obj.node().is_available_input_bus(0));
}

- (void)test_method_to_string {
    XCTAssertEqual(to_string(audio::engine::node::method::will_reset), "will_reset");
}

- (void)test_method_ostream {
    auto const values = {audio::engine::node::method::will_reset};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

@end
