//
//  yas_audio_graph_connection_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_graph_connection_tests : XCTestCase

@end

@implementation yas_audio_graph_connection_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create_connention_success {
    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::node_object src_obj;
    test::node_object dst_obj;
    uint32_t const src_bus = 0;
    uint32_t const dst_bus = 1;

    auto connection = audio::graph_connection::make_shared(src_obj.node, src_bus, dst_obj.node, dst_bus, format);

    XCTAssertTrue(connection->source_node() == src_obj.node);
    XCTAssertTrue(connection->source_bus() == src_bus);
    XCTAssertTrue(connection->destination_node() == dst_obj.node);
    XCTAssertTrue(connection->destination_bus() == dst_bus);
    XCTAssertTrue(connection->format() == format);

    XCTAssertTrue(audio::manageable_graph_node::cast(src_obj.node)->output_connection(src_bus) == connection);
    XCTAssertTrue(audio::manageable_graph_node::cast(dst_obj.node)->input_connection(dst_bus) == connection);
}

- (void)test_remove_nodes {
    auto format = audio::format({.sample_rate = 44100.0, .channel_count = 2});
    test::node_object src_obj;
    test::node_object dst_obj;
    uint32_t const src_bus = 0;
    uint32_t const dst_bus = 1;

    auto connection = audio::graph_connection::make_shared(src_obj.node, src_bus, dst_obj.node, dst_bus, format);

    audio::graph_node_removable::cast(connection)->remove_nodes();

    XCTAssertFalse(connection->source_node());
    XCTAssertFalse(connection->destination_node());
}

- (void)test_remove_nodes_separately {
    auto format = audio::format({.sample_rate = 8000.0, .channel_count = 2});
    test::node_object src_obj;
    test::node_object dst_obj;
    uint32_t const src_bus = 0;
    uint32_t const dst_bus = 1;

    auto connection = audio::graph_connection::make_shared(src_obj.node, src_bus, dst_obj.node, dst_bus, format);

    audio::graph_node_removable::cast(connection)->remove_source_node();

    XCTAssertFalse(connection->source_node());
    XCTAssertTrue(connection->destination_node());

    audio::graph_node_removable::cast(connection)->remove_destination_node();

    XCTAssertFalse(connection->destination_node());
}

@end
