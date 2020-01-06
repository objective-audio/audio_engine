//
//  yas_audio_engine_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

namespace yas::audio::engine::test {
struct test_io_core : io_core {
    void initialize() override {
    }
    void uninitialize() override {
    }

    void set_render_handler(std::optional<io_render_f>) override {
    }
    void set_maximum_frames_per_slice(uint32_t const) override {
    }

    bool start() override {
        return false;
    }
    void stop() override {
    }

    std::optional<pcm_buffer_ptr> const &input_buffer_on_render() const override {
        static std::optional<pcm_buffer_ptr> buffer = std::nullopt;
        return buffer;
    }
    std::optional<time_ptr> const &input_time_on_render() const override {
        static std::optional<time_ptr> const time = std::nullopt;
        return time;
    }
};

struct test_io_device : io_device {
    std::optional<audio::format> input_format() const override {
        return std::nullopt;
    }
    std::optional<audio::format> output_format() const override {
        return std::nullopt;
    }

    std::optional<interruptor_ptr> const &interruptor() const override {
        static std::optional<interruptor_ptr> const _nullopt = std::nullopt;
        return _nullopt;
    }

    io_core_ptr make_io_core() const override {
        return std::make_shared<test_io_core>();
    }

    chaining::chain_unsync_t<io_device::method> io_device_chain() override {
        return this->notifier->chain();
    }

    chaining::notifier_ptr<io_device::method> notifier = chaining::notifier<io_device::method>::make_shared();
};
}

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
    auto manager = audio::engine::manager::make_shared();

    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::node_object source_obj(1, 1);
    test::node_object destination_obj(1, 1);

    XCTAssertEqual(manager->nodes().size(), 0);
    XCTAssertEqual(manager->connections().size(), 0);

    auto const connection = manager->connect(source_obj.node, destination_obj.node, format);

    auto &nodes = manager->nodes();
    auto &connections = manager->connections();
    XCTAssertGreaterThanOrEqual(nodes.count(source_obj.node), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(destination_obj.node), 1);
    XCTAssertEqual(connections.size(), 1);
    XCTAssertEqual(*connections.begin(), connection);
}

- (void)test_connect_failed_no_bus {
    auto manager = audio::engine::manager::make_shared();

    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::node_object source_obj(0, 0);
    test::node_object destination_obj(0, 0);

    XCTAssertThrows(manager->connect(source_obj.node, destination_obj.node, format));
    XCTAssertEqual(manager->connections().size(), 0);
}

- (void)test_connect_and_disconnect {
    auto manager = audio::engine::manager::make_shared();

    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::node_object source_obj(1, 1);
    test::node_object relay_decor(1, 1);
    test::node_object destination_obj(1, 1);

    manager->connect(source_obj.node, relay_decor.node, format);

    auto &nodes = manager->nodes();
    XCTAssertGreaterThanOrEqual(nodes.count(source_obj.node), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(relay_decor.node), 1);
    XCTAssertEqual(nodes.count(destination_obj.node), 0);

    manager->connect(relay_decor.node, destination_obj.node, format);

    XCTAssertGreaterThanOrEqual(nodes.count(source_obj.node), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(relay_decor.node), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(destination_obj.node), 1);

    manager->disconnect(relay_decor.node);

    XCTAssertEqual(nodes.count(source_obj.node), 0);
    XCTAssertEqual(nodes.count(relay_decor.node), 0);
    XCTAssertEqual(nodes.count(destination_obj.node), 0);
}

- (void)test_add_and_remove_io {
    auto manager = audio::engine::manager::make_shared();

    XCTAssertFalse(manager->io());

    auto const &io = manager->add_io(std::nullopt);

    XCTAssertTrue(io);
    XCTAssertTrue(manager->io());
    XCTAssertTrue(manager->io() == io);

    XCTAssertNoThrow(manager->remove_io());

    XCTAssertFalse(manager->io());

    XCTAssertNoThrow(manager->remove_io());
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
