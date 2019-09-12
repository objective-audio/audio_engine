//
//  yas_audio_engine.cpp
//

#include "yas_audio_engine_manager.h"
#include <AVFoundation/AVFoundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <cpp_utils/yas_objc_ptr.h>
#include <cpp_utils/yas_result.h>
#include <cpp_utils/yas_stl_utils.h>
#include "yas_audio_engine_au.h"
#include "yas_audio_engine_node.h"
#include "yas_audio_engine_offline_output.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
#include "yas_audio_device.h"
#include "yas_audio_device_io.h"
#include "yas_audio_engine_device_io.h"
#endif

using namespace yas;

#pragma mark - audio::engine::manager::impl

struct audio::engine::manager::impl {
    ~impl() {
#if TARGET_OS_IPHONE
        if (this->_reset_observer) {
            [[NSNotificationCenter defaultCenter] removeObserver:this->_reset_observer.object()];
        }
        if (this->_route_change_observer) {
            [[NSNotificationCenter defaultCenter] removeObserver:this->_route_change_observer.object()];
        }
#endif
    }

    void prepare(std::weak_ptr<engine::manager> &weak_manager) {
#if TARGET_OS_IPHONE
        auto reset_lambda = [weak_manager](NSNotification *note) {
            if (auto engine = weak_manager.lock()) {
                engine->_reload_graph();
            }
        };

        id reset_observer =
            [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionMediaServicesWereResetNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:reset_lambda];
        this->_reset_observer.set_object(reset_observer);

        auto route_change_lambda = [weak_manager](NSNotification *note) {
            if (auto engine = weak_manager.lock()) {
                engine->_post_configuration_change();
            }
        };

        id route_change_observer =
            [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionRouteChangeNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:route_change_lambda];
        this->_route_change_observer.set_object(route_change_observer);
#endif
    }

   private:
    objc_ptr<id> _reset_observer;
    objc_ptr<id> _route_change_observer;
};

#pragma mark - audio::engine::manager

audio::engine::manager::manager() : _impl(std::make_unique<impl>()) {
}

audio::engine::manager::~manager() = default;

audio::engine::connection_ptr audio::engine::manager::connect(audio::engine::node_ptr const &source_node,
                                                              audio::engine::node_ptr const &destination_node,
                                                              audio::format const &format) {
    auto source_bus_result = source_node->next_available_output_bus();
    auto destination_bus_result = destination_node->next_available_input_bus();

    if (!source_bus_result || !destination_bus_result) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : bus is not available.");
    }

    return connect(source_node, destination_node, *source_bus_result, *destination_bus_result, format);
}

audio::engine::connection_ptr audio::engine::manager::connect(audio::engine::node_ptr const &src_node,
                                                              audio::engine::node_ptr const &dst_node,
                                                              uint32_t const src_bus_idx, uint32_t const dst_bus_idx,
                                                              audio::format const &format) {
    if (!src_node->is_available_output_bus(src_bus_idx)) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : output bus(" + std::to_string(src_bus_idx) +
                                    ") is not available.");
    }

    if (!dst_node->is_available_input_bus(dst_bus_idx)) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : input bus(" + std::to_string(dst_bus_idx) +
                                    ") is not available.");
    }

    if (!this->_node_exists(src_node)) {
        this->_attach_node(src_node);
    }

    if (!this->_node_exists(dst_node)) {
        this->_attach_node(dst_node);
    }

    auto connection = connection::make_shared(src_node, src_bus_idx, dst_node, dst_bus_idx, format);

    this->_connections.insert(connection);

    if (this->_graph) {
        this->_add_connection(connection);
        this->_update_node_connections(src_node);
        this->_update_node_connections(dst_node);
    }

    return connection;
}

void audio::engine::manager::disconnect(connection_ptr const &connection) {
    std::vector<node_ptr> update_nodes{connection->source_node(), connection->destination_node()};

    this->_remove_connection_from_nodes(connection);
    connection->removable()->remove_nodes();

    for (auto &node : update_nodes) {
        node->manageable()->update_connections();
        this->_detach_node_if_unused(node);
    }

    this->_connections.erase(connection);
}

void audio::engine::manager::disconnect(audio::engine::node_ptr const &node) {
    if (this->_node_exists(node)) {
        this->_detach_node(node);
    }
}

void audio::engine::manager::disconnect_input(audio::engine::node_ptr const &node) {
    this->_disconnect_node_with_predicate(
        [&node](connection const &connection) { return (connection.destination_node() == node); });
}

void audio::engine::manager::disconnect_input(audio::engine::node_ptr const &node, uint32_t const bus_idx) {
    this->_disconnect_node_with_predicate([&node, bus_idx](auto const &connection) {
        return (connection.destination_node() == node && connection.destination_bus == bus_idx);
    });
}

void audio::engine::manager::disconnect_output(audio::engine::node_ptr const &node) {
    this->_disconnect_node_with_predicate(
        [&node](connection const &connection) { return (connection.source_node() == node); });
}

void audio::engine::manager::disconnect_output(audio::engine::node_ptr const &node, uint32_t const bus_idx) {
    this->_disconnect_node_with_predicate([&node, bus_idx](auto const &connection) {
        return (connection.source_node() == node && connection.source_bus == bus_idx);
    });
}

audio::engine::manager::add_result_t audio::engine::manager::add_offline_output() {
    if (this->_offline_output) {
        return add_result_t{add_error_t::already_added};
    } else {
        this->_offline_output = audio::engine::offline_output::make_shared();
        return add_result_t{nullptr};
    }
}

audio::engine::manager::remove_result_t audio::engine::manager::remove_offline_output() {
    if (this->_offline_output) {
        this->_offline_output = nullptr;
        return remove_result_t{nullptr};
    } else {
        return remove_result_t{remove_error_t::already_removed};
    }
}

audio::engine::offline_output_ptr const &audio::engine::manager::offline_output() const {
    return this->_offline_output;
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

audio::engine::manager::add_result_t audio::engine::manager::add_device_io() {
    if (this->_device_io) {
        return add_result_t{add_error_t::already_added};
    } else {
        this->_set_device_io(audio::engine::device_io::make_shared());
        return add_result_t{nullptr};
    }
}

audio::engine::manager::remove_result_t audio::engine::manager::remove_device_io() {
    if (this->_device_io) {
        this->_set_device_io(nullptr);
        return remove_result_t{nullptr};
    } else {
        return remove_result_t{remove_error_t::already_removed};
    }
}

audio::engine::device_io_ptr const &audio::engine::manager::device_io() const {
    return this->_device_io;
}

#endif

audio::engine::manager::start_result_t audio::engine::manager::start_render() {
    if (auto const graph = this->_graph) {
        if (graph->is_running()) {
            return start_result_t(start_error_t::already_running);
        }
    }

    if (auto const offline_output = this->_offline_output) {
        if (offline_output->is_running()) {
            return start_result_t(start_error_t::already_running);
        }
    }

    if (!_prepare_graph()) {
        return start_result_t(start_error_t::prepare_failure);
    }

    this->_graph->start();

    return start_result_t(nullptr);
}

audio::engine::manager::start_result_t audio::engine::manager::start_offline_render(
    offline_render_f render_handler, offline_completion_f completion_handler) {
    if (auto const graph = this->_graph) {
        if (graph->is_running()) {
            return start_result_t(start_error_t::already_running);
        }
    }

    if (auto const offline_output = this->_offline_output) {
        if (offline_output->is_running()) {
            return start_result_t(start_error_t::already_running);
        }
    }

    if (!this->_prepare_graph()) {
        return start_result_t(start_error_t::prepare_failure);
    }

    auto offline_output = this->_offline_output;

    if (!offline_output) {
        return start_result_t(start_error_t::offline_output_not_found);
    }

    auto result = offline_output->manageable()->start(std::move(render_handler), std::move(completion_handler));

    if (result) {
        return start_result_t(nullptr);
    } else {
        return start_result_t(start_error_t::offline_output_starting_failure);
    }
}

void audio::engine::manager::stop() {
    if (auto graph = this->_graph) {
        graph->stop();
    }

    if (auto offline_output = this->_offline_output) {
        offline_output->manageable()->stop();
    }
}

chaining::chain_unsync_t<audio::engine::manager::chaining_pair_t> audio::engine::manager::chain() const {
    return this->_notifier->chain();
}

chaining::chain_relayed_unsync_t<audio::engine::manager_ptr, audio::engine::manager::chaining_pair_t>
audio::engine::manager::chain(method const method) const {
    return this->_notifier->chain()
        .guard([method](auto const &pair) { return pair.first == method; })
        .to([](chaining_pair_t const &pair) { return pair.second; });
}

std::unordered_set<audio::engine::node_ptr> const &audio::engine::manager::nodes() const {
    return this->_nodes;
}

audio::engine::connection_set const &audio::engine::manager::connections() const {
    return this->_connections;
}

chaining::notifier_ptr<audio::engine::manager::chaining_pair_t> &audio::engine::manager::notifier() {
    return this->_notifier;
}

void audio::engine::manager::prepare() {
    std::weak_ptr<engine::manager> weak_manager = shared_from_this();

    this->_impl->prepare(weak_manager);

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    this->_device_system_observer = device::system_chain(device::system_method::configuration_change)
                                        .perform([weak_manager](auto const &) {
                                            if (auto engine = weak_manager.lock()) {
                                                engine->_post_configuration_change();
                                            }
                                        })
                                        .end();
#endif
}

bool audio::engine::manager::_node_exists(audio::engine::node_ptr const &node) {
    return this->_nodes.count(node) > 0;
}

void audio::engine::manager::_attach_node(audio::engine::node_ptr const &node) {
    if (this->_nodes.count(node) > 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : node is already attached.");
    }

    this->_nodes.insert(node);

    node->manageable()->set_manager(shared_from_this());

    this->_add_node_to_graph(node);
}

void audio::engine::manager::_detach_node(audio::engine::node_ptr const &node) {
    if (this->_nodes.count(node) == 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : node is not attached.");
    }

    this->_disconnect_node_with_predicate([&node](connection const &connection) {
        return (connection.destination_node() == node || connection.source_node() == node);
    });

    this->_remove_node_from_graph(node);

    node->manageable()->set_manager(nullptr);

    this->_nodes.erase(node);
}

void audio::engine::manager::_detach_node_if_unused(audio::engine::node_ptr const &node) {
    auto filtered_connection = filter(_connections, [&node](auto const &connection) {
        return (connection->destination_node() == node || connection->source_node() == node);
    });

    if (filtered_connection.size() == 0) {
        this->_detach_node(node);
    }
}

bool audio::engine::manager::_prepare_graph() {
    if (this->_graph) {
        return true;
    }

    this->_graph = audio::graph::make_shared();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    if (auto &device_io = this->_device_io) {
        auto manageable = device_io->manageable();
        manageable->add_raw_device_io();
        this->_graph->add_audio_device_io(manageable->raw_device_io());
    }
#endif

    for (auto &node : this->_nodes) {
        this->_add_node_to_graph(node);
    }

    for (auto const &connection : this->_connections) {
        if (!this->_add_connection(connection)) {
            return false;
        }
    }

    this->_update_all_node_connections();

    return true;
}

void audio::engine::manager::_disconnect_node_with_predicate(std::function<bool(connection const &)> predicate) {
    auto connections =
        filter(this->_connections, [&predicate](auto const &connection) { return predicate(*connection); });

    std::unordered_set<node_ptr> update_nodes;

    for (auto connection : connections) {
        update_nodes.insert(connection->source_node());
        update_nodes.insert(connection->destination_node());
        this->_remove_connection_from_nodes(connection);
        connection->removable()->remove_nodes();
    }

    for (auto node : update_nodes) {
        node->manageable()->update_connections();
        this->_detach_node_if_unused(node);
    }

    for (auto &connection : connections) {
        this->_connections.erase(connection);
    }
}

void audio::engine::manager::_add_node_to_graph(audio::engine::node_ptr const &node) {
    if (!this->_graph) {
        return;
    }

    if (auto const &handler = node->manageable()->add_to_graph_handler()) {
        handler(*this->_graph);
    }
}

void audio::engine::manager::_remove_node_from_graph(audio::engine::node_ptr const &node) {
    if (!this->_graph) {
        return;
    }

    if (auto const &handler = node->manageable()->remove_from_graph_handler()) {
        handler(*this->_graph);
    }
}

bool audio::engine::manager::_add_connection(audio::engine::connection_ptr const &connection) {
    auto destination_node = connection->destination_node();
    auto source_node = connection->source_node();

    if (this->_nodes.count(destination_node) == 0 || this->_nodes.count(source_node) == 0) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : node is not attached.");
        return false;
    }

    destination_node->connectable()->add_connection(connection);
    source_node->connectable()->add_connection(connection);

    return true;
}

void audio::engine::manager::_remove_connection_from_nodes(audio::engine::connection_ptr const &connection) {
    if (auto source_node = connection->source_node()) {
        source_node->connectable()->remove_output_connection(connection->source_bus);
    }

    if (auto destination_node = connection->destination_node()) {
        destination_node->connectable()->remove_input_connection(connection->destination_bus);
    }
}

void audio::engine::manager::_update_node_connections(audio::engine::node_ptr const &node) {
    if (!this->_graph) {
        return;
    }

    node->manageable()->update_connections();
}

void audio::engine::manager::_update_all_node_connections() {
    if (!this->_graph) {
        return;
    }

    for (auto node : this->_nodes) {
        node->manageable()->update_connections();
    }
}

audio::engine::connection_set audio::engine::manager::_input_connections_for_destination_node(
    audio::engine::node_ptr const &node) {
    return filter(this->_connections,
                  [&node](auto const &connection) { return connection->destination_node() == node; });
}

audio::engine::connection_set audio::engine::manager::_output_connections_for_source_node(
    audio::engine::node_ptr const &node) {
    return filter(this->_connections, [&node](auto const &connection) { return connection->source_node() == node; });
}

void audio::engine::manager::_reload_graph() {
    if (auto prev_graph = this->_graph) {
        bool const prev_runnging = prev_graph->is_running();

        prev_graph->stop();

        for (auto const &node : this->_nodes) {
            this->_remove_node_from_graph(node);
        }

        this->_graph = nullptr;

        if (!this->_prepare_graph()) {
            return;
        }

        if (prev_runnging) {
            this->_graph->start();
        }
    }
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
void audio::engine::manager::_set_device_io(audio::engine::device_io_ptr const &node) {
    if (node) {
        this->_device_io = node;

        if (this->_graph) {
            auto manageable = this->_device_io->manageable();
            manageable->add_raw_device_io();
            this->_graph->add_audio_device_io(manageable->raw_device_io());
        }
    } else {
        if (this->_device_io) {
            if (this->_graph) {
                if (auto &device_io = this->_device_io->manageable()->raw_device_io()) {
                    this->_graph->remove_audio_device_io(device_io);
                }
            }

            this->_device_io->manageable()->remove_raw_device_io();
            this->_device_io = nullptr;
        }
    }
}

#endif
void audio::engine::manager::_post_configuration_change() {
    this->_notifier->notify(std::make_pair(method::configuration_change, shared_from_this()));
}

audio::engine::manager_ptr audio::engine::manager::make_shared() {
    auto shared = manager_ptr(new manager{});
    shared->prepare();
    return shared;
}

std::string yas::to_string(audio::engine::manager::method const &method) {
    switch (method) {
        case audio::engine::manager::method::configuration_change:
            return "configuration_change";
    }
}

std::string yas::to_string(audio::engine::manager::start_error_t const &error) {
    switch (error) {
        case audio::engine::manager::start_error_t::already_running:
            return "already_running";
        case audio::engine::manager::start_error_t::prepare_failure:
            return "prepare_failure";
        case audio::engine::manager::start_error_t::connection_not_found:
            return "connection_not_found";
        case audio::engine::manager::start_error_t::offline_output_not_found:
            return "offline_output_not_found";
        case audio::engine::manager::start_error_t::offline_output_starting_failure:
            return "offline_output_starting_failure";
    }
}

std::ostream &operator<<(std::ostream &os, yas::audio::engine::manager::method const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::audio::engine::manager::start_error_t const &value) {
    os << to_string(value);
    return os;
}
