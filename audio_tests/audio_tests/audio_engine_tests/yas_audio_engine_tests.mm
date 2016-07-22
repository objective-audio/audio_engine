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

    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::audio_test_node source_node(1, 1);
    test::audio_test_node destination_node(1, 1);

    XCTAssertEqual(engine.testable().nodes().size(), 0);
    XCTAssertEqual(engine.testable().connections().size(), 0);

    audio::connection connection = nullptr;
    XCTAssertNoThrow(connection = engine.connect(source_node, destination_node, format));
    XCTAssertTrue(connection);

    auto &nodes = engine.testable().nodes();
    auto &connections = engine.testable().connections();
    XCTAssertGreaterThanOrEqual(nodes.count(source_node), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(destination_node), 1);
    XCTAssertEqual(connections.size(), 1);
    XCTAssertEqual(*connections.begin(), connection);
}

- (void)test_connect_failed_no_bus {
    audio::engine engine;

    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::audio_test_node source_node(0, 0);
    test::audio_test_node destination_node(0, 0);

    audio::connection connection = nullptr;
    XCTAssertThrows(connection = engine.connect(source_node, destination_node, format));
    XCTAssertFalse(connection);
    XCTAssertEqual(engine.testable().connections().size(), 0);
}

- (void)testConnectAndDisconnect {
    audio::engine engine;

    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::audio_test_node source_node(1, 1);
    test::audio_test_node relay_node(1, 1);
    test::audio_test_node destination_node(1, 1);

    engine.connect(source_node, relay_node, format);

    auto &nodes = engine.testable().nodes();
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

- (void)test_method_to_string {
    XCTAssertEqual(to_string(audio::engine::method::configuration_change), "configuration_change");
}

- (void)test_start_error_to_string {
    XCTAssertEqual(to_string(audio::engine::start_error_t::already_running), "already_running");
    XCTAssertEqual(to_string(audio::engine::start_error_t::prepare_failure), "prepare_failure");
    XCTAssertEqual(to_string(audio::engine::start_error_t::connection_not_found), "connection_not_found");
    XCTAssertEqual(to_string(audio::engine::start_error_t::offline_output_not_found), "offline_output_not_found");
    XCTAssertEqual(to_string(audio::engine::start_error_t::offline_output_starting_failure),
                   "offline_output_starting_failure");
}

- (void)test_method_ostream {
    auto const values = {audio::engine::method::configuration_change};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

- (void)test_start_error_ostream {
    auto const errors = {audio::engine::start_error_t::already_running, audio::engine::start_error_t::prepare_failure,
                         audio::engine::start_error_t::connection_not_found,
                         audio::engine::start_error_t::offline_output_not_found,
                         audio::engine::start_error_t::offline_output_starting_failure};

    for (auto const &error : errors) {
        std::ostringstream stream;
        stream << error;
        XCTAssertEqual(stream.str(), to_string(error));
    }
}

@end
