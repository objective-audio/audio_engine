//
//  yas_audio_connection_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_connection_tests : XCTestCase

@end

@implementation yas_audio_connection_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create_connention_success {
    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::audio_test_node source_node;
    test::audio_test_node destination_node;
    uint32_t const source_bus = 0;
    uint32_t const destination_bus = 1;

    auto connection = test::connection(source_node, source_bus, destination_node, destination_bus, format);

    XCTAssertTrue(connection.source_node() == source_node);
    XCTAssertTrue(connection.source_bus() == source_bus);
    XCTAssertTrue(connection.destination_node() == destination_node);
    XCTAssertTrue(connection.destination_bus() == destination_bus);
    XCTAssertTrue(connection.format() == format);

    XCTAssertTrue(connection.node_removable());

    XCTAssertTrue(source_node.manageable().output_connection(source_bus) == connection);
    XCTAssertTrue(destination_node.manageable().input_connection(destination_bus) == connection);
}

- (void)test_create_null {
    audio::connection connection{nullptr};

    XCTAssertFalse(connection);
}

- (void)test_remove_nodes {
    auto format = audio::format({.sample_rate = 44100.0, .channel_count = 2});
    test::audio_test_node source_node;
    test::audio_test_node destination_node;
    uint32_t const source_bus = 0;
    uint32_t const destination_bus = 1;

    auto connection = test::connection(source_node, source_bus, destination_node, destination_bus, format);

    connection.node_removable().remove_nodes();

    XCTAssertFalse(connection.source_node());
    XCTAssertFalse(connection.destination_node());
}

- (void)test_remove_nodes_separately {
    auto format = audio::format({.sample_rate = 8000.0, .channel_count = 2});
    test::audio_test_node source_node;
    test::audio_test_node destination_node;
    uint32_t const source_bus = 0;
    uint32_t const destination_bus = 1;

    auto connection = test::connection(source_node, source_bus, destination_node, destination_bus, format);

    connection.node_removable().remove_source_node();

    XCTAssertFalse(connection.source_node());
    XCTAssertTrue(connection.destination_node());

    connection.node_removable().remove_destination_node();

    XCTAssertFalse(connection.destination_node());
}

- (void)test_create_connection_failed {
    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::audio_test_node source_node;
    test::audio_test_node destination_node;
    uint32_t const source_bus = 0;
    uint32_t const destination_bus = 1;

    audio::node null_node(nullptr);
    XCTAssertThrows(test::connection(null_node, source_bus, destination_node, destination_bus, format));
    XCTAssertThrows(test::connection(source_node, source_bus, null_node, destination_bus, format));
}

- (void)test_empty_connection {
    audio::connection connection(nullptr);

    XCTAssertFalse(connection.source_node());
    XCTAssertFalse(connection.destination_node());
}

@end
