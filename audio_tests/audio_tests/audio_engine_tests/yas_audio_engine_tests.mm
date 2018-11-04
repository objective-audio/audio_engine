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
    audio::engine::manager manager;

    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::audio_test_node_object source_obj(1, 1);
    test::audio_test_node_object destination_obj(1, 1);

    XCTAssertEqual(manager.nodes().size(), 0);
    XCTAssertEqual(manager.connections().size(), 0);

    audio::engine::connection connection = nullptr;
    XCTAssertNoThrow(connection = manager.connect(source_obj.node(), destination_obj.node(), format));
    XCTAssertTrue(connection);

    auto &nodes = manager.nodes();
    auto &connections = manager.connections();
    XCTAssertGreaterThanOrEqual(nodes.count(source_obj.node()), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(destination_obj.node()), 1);
    XCTAssertEqual(connections.size(), 1);
    XCTAssertEqual(*connections.begin(), connection);
}

- (void)test_connect_failed_no_bus {
    audio::engine::manager manager;

    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::audio_test_node_object source_obj(0, 0);
    test::audio_test_node_object destination_obj(0, 0);

    audio::engine::connection connection = nullptr;
    XCTAssertThrows(connection = manager.connect(source_obj.node(), destination_obj.node(), format));
    XCTAssertFalse(connection);
    XCTAssertEqual(manager.connections().size(), 0);
}

- (void)test_connect_and_disconnect {
    audio::engine::manager manager;

    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::audio_test_node_object source_obj(1, 1);
    test::audio_test_node_object relay_decor(1, 1);
    test::audio_test_node_object destination_obj(1, 1);

    manager.connect(source_obj.node(), relay_decor.node(), format);

    auto &nodes = manager.nodes();
    XCTAssertGreaterThanOrEqual(nodes.count(source_obj.node()), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(relay_decor.node()), 1);
    XCTAssertEqual(nodes.count(destination_obj.node()), 0);

    manager.connect(relay_decor.node(), destination_obj.node(), format);

    XCTAssertGreaterThanOrEqual(nodes.count(source_obj.node()), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(relay_decor.node()), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(destination_obj.node()), 1);

    manager.disconnect(relay_decor.node());

    XCTAssertEqual(nodes.count(source_obj.node()), 0);
    XCTAssertEqual(nodes.count(relay_decor.node()), 0);
    XCTAssertEqual(nodes.count(destination_obj.node()), 0);
}

- (void)test_configuration_change_notification {
    audio::engine::manager manager;

    XCTestExpectation *expectation = [self expectationWithDescription:@"configuration change"];

    auto chain = manager.chain().perform([expectation](auto const &) { [expectation fulfill]; }).end();

#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] postNotificationName:AVAudioSessionRouteChangeNotification object:nil];
#elif TARGET_OS_MAC
    audio::device::system_notifier().notify(
        std::make_pair(audio::device::system_method::configuration_change,
                       audio::device::change_info{std::vector<audio::device::property_info>{}}));
#endif

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)test_add_and_remove_offline_output {
    audio::engine::manager manager;

    XCTAssertFalse(manager.offline_output());

    XCTAssertTrue(manager.add_offline_output());

    auto add_result = manager.add_offline_output();
    XCTAssertFalse(add_result);
    XCTAssertEqual(add_result.error(), audio::engine::manager::add_error_t::already_added);

    XCTAssertTrue(manager.offline_output());

    XCTAssertTrue(manager.remove_offline_output());

    auto remove_result = manager.remove_offline_output();
    XCTAssertFalse(remove_result);
    XCTAssertEqual(remove_result.error(), audio::engine::manager::remove_error_t::already_removed);

    XCTAssertFalse(manager.offline_output());
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

- (void)test_add_and_remove_device_io {
    audio::engine::manager manager;

    XCTAssertFalse(manager.device_io());

    XCTAssertTrue(manager.add_device_io());

    auto add_result = manager.add_device_io();
    XCTAssertFalse(add_result);
    XCTAssertEqual(add_result.error(), audio::engine::manager::add_error_t::already_added);

    XCTAssertTrue(manager.device_io());

    XCTAssertTrue(manager.remove_device_io());

    auto remove_result = manager.remove_device_io();
    XCTAssertFalse(remove_result);
    XCTAssertEqual(remove_result.error(), audio::engine::manager::remove_error_t::already_removed);

    XCTAssertFalse(manager.device_io());
}

#endif

- (void)test_method_to_string {
    XCTAssertEqual(to_string(audio::engine::manager::method::configuration_change), "configuration_change");
}

- (void)test_start_error_to_string {
    XCTAssertEqual(to_string(audio::engine::manager::start_error_t::already_running), "already_running");
    XCTAssertEqual(to_string(audio::engine::manager::start_error_t::prepare_failure), "prepare_failure");
    XCTAssertEqual(to_string(audio::engine::manager::start_error_t::connection_not_found), "connection_not_found");
    XCTAssertEqual(to_string(audio::engine::manager::start_error_t::offline_output_not_found),
                   "offline_output_not_found");
    XCTAssertEqual(to_string(audio::engine::manager::start_error_t::offline_output_starting_failure),
                   "offline_output_starting_failure");
}

- (void)test_method_ostream {
    auto const values = {audio::engine::manager::method::configuration_change};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

- (void)test_start_error_ostream {
    auto const errors = {audio::engine::manager::start_error_t::already_running,
                         audio::engine::manager::start_error_t::prepare_failure,
                         audio::engine::manager::start_error_t::connection_not_found,
                         audio::engine::manager::start_error_t::offline_output_not_found,
                         audio::engine::manager::start_error_t::offline_output_starting_failure};

    for (auto const &error : errors) {
        std::ostringstream stream;
        stream << error;
        XCTAssertEqual(stream.str(), to_string(error));
    }
}

@end
