//
//  yas_audio_graph_node_tests.m
//

#import <audio/yas_audio_rendering_connection.h>
#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_graph_node_tests : XCTestCase

@end

@implementation yas_audio_graph_node_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create_audio_node {
    test::node_object obj;

    XCTAssertEqual(obj.node->input_bus_count(), 2);
    XCTAssertEqual(obj.node->output_bus_count(), 1);

    XCTAssertTrue(audio::manageable_graph_node::cast(obj.node));

    XCTAssertEqual(audio::manageable_graph_node::cast(obj.node)->input_connections().size(), 0);
    XCTAssertEqual(audio::manageable_graph_node::cast(obj.node)->output_connections().size(), 0);
    XCTAssertEqual(*obj.node->next_available_input_bus(), 0);
    XCTAssertEqual(*obj.node->next_available_output_bus(), 0);
}

- (void)test_connection {
    test::node_object src_obj;
    test::node_object dst_obj;
    auto format = audio::format({.sample_rate = 44100.0, .channel_count = 2});
    auto source_bus_result = src_obj.node->next_available_input_bus();
    auto destination_bus_result = dst_obj.node->next_available_output_bus();

    XCTAssertTrue(source_bus_result);
    auto source_bus = *source_bus_result;
    XCTAssertEqual(source_bus, 0);

    XCTAssertTrue(destination_bus_result);
    auto destination_bus = *destination_bus_result;
    XCTAssertEqual(destination_bus, 0);

    if (auto const connection =
            audio::graph_connection::make_shared(src_obj.node, source_bus, dst_obj.node, destination_bus, format)) {
        XCTAssertEqual(audio::manageable_graph_node::cast(src_obj.node)->output_connections().size(), 1);
        XCTAssertEqual(audio::manageable_graph_node::cast(dst_obj.node)->input_connections().size(), 1);
        XCTAssertEqual(audio::manageable_graph_node::cast(src_obj.node)->output_connection(source_bus), connection);
        XCTAssertEqual(audio::manageable_graph_node::cast(dst_obj.node)->input_connection(destination_bus), connection);
        XCTAssertEqual(src_obj.node->output_format(source_bus), format);
        XCTAssertEqual(dst_obj.node->input_format(destination_bus), format);

        XCTAssertFalse(src_obj.node->output_format(source_bus + 1));
        XCTAssertFalse(dst_obj.node->input_format(destination_bus + 1));

        XCTAssertFalse(src_obj.node->next_available_output_bus());
        XCTAssertTrue(dst_obj.node->next_available_input_bus());
        destination_bus_result = dst_obj.node->next_available_input_bus();
        XCTAssertEqual(*destination_bus_result, 1);
    }

    source_bus_result = src_obj.node->next_available_output_bus();
    destination_bus_result = dst_obj.node->next_available_input_bus();
    XCTAssertEqual(*source_bus_result, 0);
    XCTAssertEqual(*destination_bus_result, 0);
}

- (void)test_reset {
    test::node_object src_obj;
    test::node_object dst_obj;
    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    auto source_bus = *src_obj.node->next_available_output_bus();
    auto destination_bus = *dst_obj.node->next_available_input_bus();

    auto connection =
        audio::graph_connection::make_shared(src_obj.node, source_bus, dst_obj.node, destination_bus, format);

    XCTAssertEqual(audio::manageable_graph_node::cast(src_obj.node)->output_connections().size(), 1);
    XCTAssertEqual(audio::manageable_graph_node::cast(dst_obj.node)->input_connections().size(), 1);

    src_obj.node->reset();
    XCTAssertEqual(audio::manageable_graph_node::cast(src_obj.node)->output_connections().size(), 0);

    dst_obj.node->reset();
    XCTAssertEqual(audio::manageable_graph_node::cast(dst_obj.node)->input_connections().size(), 0);
}

- (void)test_set_graph {
    auto node = audio::graph_node::make_shared({});
    auto graph = audio::graph::make_shared();

    audio::manageable_graph_node::cast(node)->set_graph(graph);

    XCTAssertEqual(graph, node->graph());

    audio::manageable_graph_node::cast(node)->set_graph(audio::graph_ptr{nullptr});
}

- (void)test_available_bus {
    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::node_object src_obj_0;
    test::node_object src_obj_1;
    test::node_object dst_obj;

    XCTAssertTrue(src_obj_0.node->is_available_output_bus(0));
    XCTAssertFalse(src_obj_0.node->is_available_output_bus(1));
    XCTAssertTrue(src_obj_1.node->is_available_output_bus(0));
    XCTAssertTrue(dst_obj.node->is_available_input_bus(0));
    XCTAssertTrue(dst_obj.node->is_available_input_bus(1));
    XCTAssertFalse(dst_obj.node->is_available_input_bus(2));

    auto connection_1 = audio::graph_connection::make_shared(src_obj_1.node, 0, dst_obj.node, 1, format);

    XCTAssertFalse(src_obj_1.node->is_available_output_bus(0));
    XCTAssertTrue(dst_obj.node->is_available_input_bus(0));
    XCTAssertFalse(dst_obj.node->is_available_input_bus(1));

    auto connection_0 = audio::graph_connection::make_shared(src_obj_0.node, 0, dst_obj.node, 0, format);

    XCTAssertFalse(src_obj_0.node->is_available_output_bus(0));
    XCTAssertFalse(dst_obj.node->is_available_input_bus(0));
}

- (void)test_method_to_string {
    XCTAssertEqual(to_string(audio::graph_node::method::will_reset), "will_reset");
}

- (void)test_method_ostream {
    auto const values = {audio::graph_node::method::will_reset};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

@end
