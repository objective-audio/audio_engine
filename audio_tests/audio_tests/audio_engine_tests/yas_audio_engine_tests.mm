//
//  yas_audio_engine_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_engine_tests : XCTestCase

@end

@implementation yas_audio_engine_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_connect_success {
    audio::engine engine;

    auto format = audio::format(48000.0, 2);
    test::audio_test_node source_node(1, 1);
    test::audio_test_node destination_node(1, 1);

    XCTAssertEqual(audio::engine::testable::nodes(engine).size(), 0);
    XCTAssertEqual(audio::engine::testable::connections(engine).size(), 0);

    audio::connection connection = nullptr;
    XCTAssertNoThrow(connection = engine.connect(source_node, destination_node, format));
    XCTAssertTrue(connection);

    auto &nodes = audio::engine::testable::nodes(engine);
    auto &connections = audio::engine::testable::connections(engine);
    XCTAssertGreaterThanOrEqual(nodes.count(source_node), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(destination_node), 1);
    XCTAssertEqual(connections.size(), 1);
    XCTAssertEqual(*connections.begin(), connection);
}

- (void)test_connect_failed_no_bus {
    audio::engine engine;

    auto format = audio::format(48000.0, 2);
    test::audio_test_node source_node(0, 0);
    test::audio_test_node destination_node(0, 0);

    audio::connection connection = nullptr;
    XCTAssertThrows(connection = engine.connect(source_node, destination_node, format));
    XCTAssertFalse(connection);
    XCTAssertEqual(audio::engine::testable::connections(engine).size(), 0);
}

- (void)testConnectAndDisconnect {
    audio::engine engine;

    auto format = audio::format(48000.0, 2);
    test::audio_test_node source_node(1, 1);
    test::audio_test_node relay_node(1, 1);
    test::audio_test_node destination_node(1, 1);

    engine.connect(source_node, relay_node, format);

    auto &nodes = audio::engine::testable::nodes(engine);
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

- (void)testConfigurationChangeNotification {
    audio::engine engine;

    XCTestExpectation *expectation = [self expectationWithDescription:@"configuration change"];

    audio::engine::observer_t observer;
    observer.add_wild_card_handler(engine.subject(), [expectation](auto const &) { [expectation fulfill]; });

#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] postNotificationName:AVAudioSessionRouteChangeNotification object:nil];
#elif TARGET_OS_MAC
    audio::device::system_subject().notify(audio::device::method::configuration_change,
                                           audio::device::change_info{std::vector<audio::device::property_info>{}});
#endif

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
