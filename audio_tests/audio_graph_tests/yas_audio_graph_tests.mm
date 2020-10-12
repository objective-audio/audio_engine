//
//  yas_audio_graph_tests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

namespace yas::audio::test {
struct test_io_core : io_core {
    void set_render_handler(std::optional<io_render_f>) override {
    }
    void set_maximum_frames_per_slice(uint32_t const) override {
    }

    bool start() override {
        return false;
    }
    void stop() override {
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

@interface yas_audio_graph_tests : XCTestCase

@end

@implementation yas_audio_graph_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_connect_success {
    auto graph = audio::graph::make_shared();

    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::node_object source_obj(1, 1);
    test::node_object destination_obj(1, 1);

    XCTAssertEqual(graph->nodes().size(), 0);
    XCTAssertEqual(graph->connections().size(), 0);

    auto const connection = graph->connect(source_obj.node, destination_obj.node, format);

    auto &nodes = graph->nodes();
    auto &connections = graph->connections();
    XCTAssertGreaterThanOrEqual(nodes.count(source_obj.node), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(destination_obj.node), 1);
    XCTAssertEqual(connections.size(), 1);
    XCTAssertEqual(*connections.begin(), connection);
}

- (void)test_connect_failed_no_bus {
    auto graph = audio::graph::make_shared();

    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::node_object source_obj(0, 0);
    test::node_object destination_obj(0, 0);

    XCTAssertThrows(graph->connect(source_obj.node, destination_obj.node, format));
    XCTAssertEqual(graph->connections().size(), 0);
}

- (void)test_connect_and_disconnect {
    auto graph = audio::graph::make_shared();

    auto format = audio::format({.sample_rate = 48000.0, .channel_count = 2});
    test::node_object source_obj(1, 1);
    test::node_object relay_decor(1, 1);
    test::node_object destination_obj(1, 1);

    graph->connect(source_obj.node, relay_decor.node, format);

    auto &nodes = graph->nodes();
    XCTAssertGreaterThanOrEqual(nodes.count(source_obj.node), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(relay_decor.node), 1);
    XCTAssertEqual(nodes.count(destination_obj.node), 0);

    graph->connect(relay_decor.node, destination_obj.node, format);

    XCTAssertGreaterThanOrEqual(nodes.count(source_obj.node), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(relay_decor.node), 1);
    XCTAssertGreaterThanOrEqual(nodes.count(destination_obj.node), 1);

    graph->disconnect(relay_decor.node);

    XCTAssertEqual(nodes.count(source_obj.node), 0);
    XCTAssertEqual(nodes.count(relay_decor.node), 0);
    XCTAssertEqual(nodes.count(destination_obj.node), 0);
}

- (void)test_add_and_remove_io {
    auto graph = audio::graph::make_shared();

    XCTAssertFalse(graph->io());

    auto const &io = graph->add_io(std::nullopt);

    XCTAssertTrue(io);
    XCTAssertTrue(graph->io());
    XCTAssertTrue(graph->io() == io);

    XCTAssertNoThrow(graph->remove_io());

    XCTAssertFalse(graph->io());

    XCTAssertNoThrow(graph->remove_io());
}

- (void)test_start_error_to_string {
    XCTAssertEqual(to_string(audio::graph::start_error_t::already_running), "already_running");
    XCTAssertEqual(to_string(audio::graph::start_error_t::prepare_failure), "prepare_failure");
    XCTAssertEqual(to_string(audio::graph::start_error_t::connection_not_found), "connection_not_found");
}

- (void)test_start_error_ostream {
    auto const errors = {audio::graph::start_error_t::already_running, audio::graph::start_error_t::prepare_failure,
                         audio::graph::start_error_t::connection_not_found};

    for (auto const &error : errors) {
        std::ostringstream stream;
        stream << error;
        XCTAssertEqual(stream.str(), to_string(error));
    }
}

@end
