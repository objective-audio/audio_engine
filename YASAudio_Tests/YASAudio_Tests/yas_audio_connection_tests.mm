//
//  yas_audio_connection_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "yas_audio.h"
#import "yas_audio_test_utils.h"

@interface yas_audio_connection_tests : XCTestCase

@end

@implementation yas_audio_connection_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_create_connention_success
{
    auto format = yas::audio_format::create(48000.0, 2);
    auto source_node = yas::test::audio_test_node::create();
    auto destination_node = yas::test::audio_test_node::create();
    const UInt32 source_bus = 0;
    const UInt32 destination_bus = 1;

    auto connection = yas::audio_connection::private_access::create(source_node, source_bus, destination_node,
                                                                    destination_bus, format);

    XCTAssertTrue(connection->source_node() == source_node);
    XCTAssertTrue(connection->source_bus() == source_bus);
    XCTAssertTrue(connection->destination_node() == destination_node);
    XCTAssertTrue(connection->destination_bus() == destination_bus);
    XCTAssertTrue(connection->format() == format);

    XCTAssertTrue(yas::audio_node::private_access::output_connection(source_node, source_bus) == connection);
    XCTAssertTrue(yas::audio_node::private_access::input_connection(destination_node, destination_bus) == connection);
}

- (void)test_remove_nodes
{
    auto format = yas::audio_format::create(44100.0, 2);
    auto source_node = yas::test::audio_test_node::create();
    auto destination_node = yas::test::audio_test_node::create();
    const UInt32 source_bus = 0;
    const UInt32 destination_bus = 1;

    auto connection = yas::audio_connection::private_access::create(source_node, source_bus, destination_node,
                                                                    destination_bus, format);

    yas::audio_connection::private_access::remove_nodes(connection);

    XCTAssertTrue(connection->source_node() == nullptr);
    XCTAssertTrue(connection->destination_node() == nullptr);
}

- (void)test_remove_nodes_separately
{
    auto format = yas::audio_format::create(8000.0, 2);
    auto source_node = yas::test::audio_test_node::create();
    auto destination_node = yas::test::audio_test_node::create();
    const UInt32 source_bus = 0;
    const UInt32 destination_bus = 1;

    auto connection = yas::audio_connection::private_access::create(source_node, source_bus, destination_node,
                                                                    destination_bus, format);

    yas::audio_connection::private_access::remove_source_node(connection);

    XCTAssertTrue(connection->source_node() == nullptr);
    XCTAssertFalse(connection->destination_node() == nullptr);

    yas::audio_connection::private_access::remove_destination_node(connection);

    XCTAssertTrue(connection->destination_node() == nullptr);
}

- (void)test_create_connection_failed
{
    auto format = yas::audio_format::create(48000.0, 2);
    auto source_node = yas::test::audio_test_node::create();
    auto destination_node = yas::test::audio_test_node::create();
    const UInt32 source_bus = 0;
    const UInt32 destination_bus = 1;

    XCTAssertThrows(
        yas::audio_connection::private_access::create(nullptr, source_bus, destination_node, destination_bus, format));

    XCTAssertThrows(
        yas::audio_connection::private_access::create(source_node, source_bus, nullptr, destination_bus, format));

    XCTAssertThrows(yas::audio_connection::private_access::create(source_node, source_bus, destination_node,
                                                                  destination_bus, nullptr));
}

@end
