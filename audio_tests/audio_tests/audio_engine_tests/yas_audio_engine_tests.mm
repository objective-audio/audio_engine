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
    test::audio_test_node_ext source_ext(1, 1);
    test::audio_test_node_ext destination_ext(1, 1);

    XCTAssertEqual(engine.nodes().size(), 0);
    XCTAssertEqual(engine.connections().size(), 0);

    audio::connection connection = nullptr;
    XCTAssertNoThrow(connection = engine.connect(source_ext.node(), destination_ext.node(), format));
    XCTAssertTrue(connection);

    auto &nodes = engine.nodes();
    auto &connections = engine.connections();
    XCTAssertGreaterThanOrEqual(nodes.count(source_ext.node()), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(destination_ext.node()), 1);
    XCTAssertEqual(connections.size(), 1);
    XCTAssertEqual(*connections.begin(), connection);
}

- (void)test_connect_failed_no_bus {
    audio::engine engine;

    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::audio_test_node_ext source_ext(0, 0);
    test::audio_test_node_ext destination_ext(0, 0);

    audio::connection connection = nullptr;
    XCTAssertThrows(connection = engine.connect(source_ext.node(), destination_ext.node(), format));
    XCTAssertFalse(connection);
    XCTAssertEqual(engine.connections().size(), 0);
}

- (void)test_connect_and_disconnect {
    audio::engine engine;

    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::audio_test_node_ext source_ext(1, 1);
    test::audio_test_node_ext relay_ext(1, 1);
    test::audio_test_node_ext destination_ext(1, 1);

    engine.connect(source_ext.node(), relay_ext.node(), format);

    auto &nodes = engine.nodes();
    XCTAssertGreaterThanOrEqual(nodes.count(source_ext.node()), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(relay_ext.node()), 1);
    XCTAssertEqual(nodes.count(destination_ext.node()), 0);

    engine.connect(relay_ext.node(), destination_ext.node(), format);

    XCTAssertGreaterThanOrEqual(nodes.count(source_ext.node()), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(relay_ext.node()), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(destination_ext.node()), 1);

    engine.disconnect(relay_ext.node());

    XCTAssertEqual(nodes.count(source_ext.node()), 0);
    XCTAssertEqual(nodes.count(relay_ext.node()), 0);
    XCTAssertEqual(nodes.count(destination_ext.node()), 0);
}

- (void)test_configuration_change_notification {
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

- (void)test_add_and_remove_offline_output_extension {
    audio::engine engine;

    XCTAssertFalse(engine.offline_output_extension());

    XCTAssertTrue(engine.add_offline_output_extension());

    auto add_result = engine.add_offline_output_extension();
    XCTAssertFalse(add_result);
    XCTAssertEqual(add_result.error(), audio::engine::add_error_t::already_added);

    XCTAssertTrue(engine.offline_output_extension());

    XCTAssertTrue(engine.remove_offline_output_extension());

    auto remove_result = engine.remove_offline_output_extension();
    XCTAssertFalse(remove_result);
    XCTAssertEqual(remove_result.error(), audio::engine::remove_error_t::already_removed);

    XCTAssertFalse(engine.offline_output_extension());
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

- (void)test_add_and_remove_device_io_extension {
    audio::engine engine;

    XCTAssertFalse(engine.device_io_extension());

    XCTAssertTrue(engine.add_device_io_extension());

    auto add_result = engine.add_device_io_extension();
    XCTAssertFalse(add_result);
    XCTAssertEqual(add_result.error(), audio::engine::add_error_t::already_added);

    XCTAssertTrue(engine.device_io_extension());

    XCTAssertTrue(engine.remove_device_io_extension());

    auto remove_result = engine.remove_device_io_extension();
    XCTAssertFalse(remove_result);
    XCTAssertEqual(remove_result.error(), audio::engine::remove_error_t::already_removed);

    XCTAssertFalse(engine.device_io_extension());
}

#endif

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
