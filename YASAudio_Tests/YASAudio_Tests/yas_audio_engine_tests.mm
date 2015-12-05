//
//  yas_audio_engine_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

@interface yas_audio_engine_tests : XCTestCase

@end

@implementation yas_audio_engine_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_connect_success
{
    yas::audio_engine engine;

    auto format = yas::audio::format(48000.0, 2);
    yas::test::audio_test_node source_node(1, 1);
    yas::test::audio_test_node destination_node(1, 1);

    XCTAssertEqual(yas::audio_engine::private_access::nodes(engine).size(), 0);
    XCTAssertEqual(yas::audio_engine::private_access::connections(engine).size(), 0);

    yas::audio_connection connection = nullptr;
    XCTAssertNoThrow(connection = engine.connect(source_node, destination_node, format));
    XCTAssertTrue(connection);

    auto &nodes = yas::audio_engine::private_access::nodes(engine);
    auto &connections = yas::audio_engine::private_access::connections(engine);
    XCTAssertGreaterThanOrEqual(nodes.count(source_node), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(destination_node), 1);
    XCTAssertEqual(connections.size(), 1);
    XCTAssertEqual(*connections.begin(), connection);
}

- (void)test_connect_failed_no_bus
{
    yas::audio_engine engine;

    auto format = yas::audio::format(48000.0, 2);
    yas::test::audio_test_node source_node(0, 0);
    yas::test::audio_test_node destination_node(0, 0);

    yas::audio_connection connection = nullptr;
    XCTAssertThrows(connection = engine.connect(source_node, destination_node, format));
    XCTAssertFalse(connection);
    XCTAssertEqual(yas::audio_engine::private_access::connections(engine).size(), 0);
}

- (void)testConnectAndDisconnect
{
    yas::audio_engine engine;

    auto format = yas::audio::format(48000.0, 2);
    yas::test::audio_test_node source_node(1, 1);
    yas::test::audio_test_node relay_node(1, 1);
    yas::test::audio_test_node destination_node(1, 1);

    engine.connect(source_node, relay_node, format);

    auto &nodes = yas::audio_engine::private_access::nodes(engine);
    XCTAssertGreaterThanOrEqual(nodes.count(source_node), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(relay_node), 1);
    XCTAssertEqual(nodes.count(destination_node), 0);

    engine.connect(relay_node, destination_node, format);

    XCTAssertGreaterThanOrEqual(nodes.count(source_node), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(relay_node), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(destination_node), 1);

    engine.disconnect(relay_node);

    XCTAssertEqual(nodes.count(source_node), 0);
    XCTAssertEqual(nodes.count(relay_node), 0);
    XCTAssertEqual(nodes.count(destination_node), 0);
}

- (void)testConfigurationChangeNotification
{
    yas::audio_engine engine;

    XCTestExpectation *expectation = [self expectationWithDescription:@"configuration change"];

    yas::observer<yas::audio_engine> observer;
    observer.add_wild_card_handler(engine.subject(),
                                   [expectation](const auto &method, const auto &info) { [expectation fulfill]; });

#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] postNotificationName:AVAudioSessionRouteChangeNotification object:nil];
#elif TARGET_OS_MAC
    yas::audio_device::system_subject().notify(
        yas::audio_device::configuration_change_key,
        yas::audio_device::change_info{std::vector<yas::audio_device::property_info>{}});
#endif

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
