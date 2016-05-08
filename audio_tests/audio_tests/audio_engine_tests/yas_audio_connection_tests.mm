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
    auto format = audio::format(48000.0, 2);
    test::audio_test_node source_node;
    test::audio_test_node destination_node;
    const UInt32 source_bus = 0;
    const UInt32 destination_bus = 1;

    auto connection =
        audio::connection::private_access::create(source_node, source_bus, destination_node, destination_bus, format);

    XCTAssertTrue(connection.source_node() == source_node);
    XCTAssertTrue(connection.source_bus() == source_bus);
    XCTAssertTrue(connection.destination_node() == destination_node);
    XCTAssertTrue(connection.destination_bus() == destination_bus);
    XCTAssertTrue(connection.format() == format);

    XCTAssertTrue(source_node.manageable_node().output_connection(source_bus) == connection);
    XCTAssertTrue(destination_node.manageable_node().input_connection(destination_bus) == connection);
}

- (void)test_remove_nodes {
    auto format = audio::format(44100.0, 2);
    test::audio_test_node source_node;
    test::audio_test_node destination_node;
    const UInt32 source_bus = 0;
    const UInt32 destination_bus = 1;

    auto connection =
        audio::connection::private_access::create(source_node, source_bus, destination_node, destination_bus, format);

    connection.node_removable().remove_nodes();

    XCTAssertFalse(connection.source_node());
    XCTAssertFalse(connection.destination_node());
}

- (void)test_remove_nodes_separately {
    auto format = audio::format(8000.0, 2);
    test::audio_test_node source_node;
    test::audio_test_node destination_node;
    const UInt32 source_bus = 0;
    const UInt32 destination_bus = 1;

    auto connection =
        audio::connection::private_access::create(source_node, source_bus, destination_node, destination_bus, format);

    connection.node_removable().remove_source_node();

    XCTAssertFalse(connection.source_node());
    XCTAssertTrue(connection.destination_node());

    connection.node_removable().remove_destination_node();

    XCTAssertFalse(connection.destination_node());
}

- (void)test_create_connection_failed {
    auto format = audio::format(48000.0, 2);
    test::audio_test_node source_node;
    test::audio_test_node destination_node;
    const UInt32 source_bus = 0;
    const UInt32 destination_bus = 1;

    audio::node null_node(nullptr);
    XCTAssertThrows(
        audio::connection::private_access::create(null_node, source_bus, destination_node, destination_bus, format));
    XCTAssertThrows(
        audio::connection::private_access::create(source_node, source_bus, null_node, destination_bus, format));
}

- (void)test_empty_connection {
    audio::connection connection(nullptr);

    XCTAssertFalse(connection.source_node());
    XCTAssertFalse(connection.destination_node());
}

@end
