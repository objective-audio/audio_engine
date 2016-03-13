//
//  yas_audio_connection_tests.m
//

#import "yas_audio_test_utils.h"

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
    auto format = yas::audio::format(48000.0, 2);
    yas::test::audio_test_node source_node;
    yas::test::audio_test_node destination_node;
    const UInt32 source_bus = 0;
    const UInt32 destination_bus = 1;

    auto connection = yas::audio::connection::private_access::create(source_node, source_bus, destination_node,
                                                                     destination_bus, format);

    XCTAssertTrue(connection.source_node() == source_node);
    XCTAssertTrue(connection.source_bus() == source_bus);
    XCTAssertTrue(connection.destination_node() == destination_node);
    XCTAssertTrue(connection.destination_bus() == destination_bus);
    XCTAssertTrue(connection.format() == format);

    XCTAssertTrue(source_node.manageable_node().output_connection(source_bus) == connection);
    XCTAssertTrue(destination_node.manageable_node().input_connection(destination_bus) == connection);
}

- (void)test_remove_nodes {
    auto format = yas::audio::format(44100.0, 2);
    yas::test::audio_test_node source_node;
    yas::test::audio_test_node destination_node;
    const UInt32 source_bus = 0;
    const UInt32 destination_bus = 1;

    auto connection = yas::audio::connection::private_access::create(source_node, source_bus, destination_node,
                                                                     destination_bus, format);

    yas::audio::connection::private_access::remove_nodes(connection);

    XCTAssertFalse(connection.source_node());
    XCTAssertFalse(connection.destination_node());
}

- (void)test_remove_nodes_separately {
    auto format = yas::audio::format(8000.0, 2);
    yas::test::audio_test_node source_node;
    yas::test::audio_test_node destination_node;
    const UInt32 source_bus = 0;
    const UInt32 destination_bus = 1;

    auto connection = yas::audio::connection::private_access::create(source_node, source_bus, destination_node,
                                                                     destination_bus, format);

    yas::audio::connection::private_access::remove_source_node(connection);

    XCTAssertFalse(connection.source_node());
    XCTAssertTrue(connection.destination_node());

    yas::audio::connection::private_access::remove_destination_node(connection);

    XCTAssertFalse(connection.destination_node());
}

- (void)test_create_connection_failed {
    auto format = yas::audio::format(48000.0, 2);
    yas::test::audio_test_node source_node;
    yas::test::audio_test_node destination_node;
    const UInt32 source_bus = 0;
    const UInt32 destination_bus = 1;

    yas::audio::node null_node(nullptr);
    XCTAssertThrows(yas::audio::connection::private_access::create(null_node, source_bus, destination_node,
                                                                   destination_bus, format));
    XCTAssertThrows(
        yas::audio::connection::private_access::create(source_node, source_bus, null_node, destination_bus, format));
}

- (void)test_empty_connection {
    yas::audio::connection connection(nullptr);

    XCTAssertFalse(connection.source_node());
    XCTAssertFalse(connection.destination_node());
}

@end
