//
//  yas_audio_engine.cpp
//

#include <AVFoundation/AVFoundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include "yas_audio_engine_manager.h"
#include "yas_audio_graph.h"
#include "yas_audio_engine_node.h"
#include "yas_audio_engine_offline_output.h"
#include "yas_audio_engine_au.h"
#include "yas_objc_ptr.h"
#include "yas_observing.h"
#include "yas_result.h"
#include "yas_stl_utils.h"

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
#include "yas_audio_device.h"
#include "yas_audio_device_io.h"
#include "yas_audio_engine_device_io.h"
#endif

using namespace yas;

namespace yas::audio {
class connection_for_engine : public audio::engine::connection {
   public:
    connection_for_engine(audio::engine::node &src_node, uint32_t const src_bus, audio::engine::node &dst_node,
                          uint32_t const dst_bus, audio::format const &format)
        : audio::engine::connection(src_node, src_bus, dst_node, dst_bus, format) {
    }
};
}

#pragma mark - audio::engine::manager::impl

struct audio::engine::manager::impl : base::impl {
    weak<manager> _weak_manager;
    subject_t _subject;

    ~impl() {
#if TARGET_OS_IPHONE
        if (_reset_observer) {
            [[NSNotificationCenter defaultCenter] removeObserver:_reset_observer.object()];
        }
        if (_route_change_observer) {
            [[NSNotificationCenter defaultCenter] removeObserver:_route_change_observer.object()];
        }
#endif
    }

    void prepare(manager const &manager) {
        _weak_manager = manager;

#if TARGET_OS_IPHONE
        auto reset_lambda = [weak_manager = _weak_manager](NSNotification * note) {
            if (auto engine = weak_manager.lock()) {
                engine.impl_ptr<impl>()->reload_graph();
            }
        };

        id reset_observer =
            [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionMediaServicesWereResetNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:reset_lambda];
        _reset_observer.set_object(reset_observer);

        auto route_change_lambda = [weak_manager = _weak_manager](NSNotification * note) {
            if (auto engine = weak_manager.lock()) {
                engine.impl_ptr<impl>()->post_configuration_change();
            }
        };

        id route_change_observer =
            [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionRouteChangeNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:route_change_lambda];
        _route_change_observer.set_object(route_change_observer);

#elif TARGET_OS_MAC
        _device_observer.add_handler(device::system_subject(), device::method::configuration_change,
                                     [weak_manager = _weak_manager](auto const &context) {
                                         if (auto engine = weak_manager.lock()) {
                                             engine.impl_ptr<impl>()->post_configuration_change();
                                         }
                                     });
#endif
    }

    bool node_exists(audio::engine::node const &node) {
        return _nodes.count(node) > 0;
    }

    void attach_node(audio::engine::node &node) {
        if (!node) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        }

        if (_nodes.count(node) > 0) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : node is already attached.");
        }

        _nodes.insert(node);

        node.manageable().set_manager(_weak_manager.lock());

        add_node_to_graph(node);
    }

    void detach_node(audio::engine::node &node) {
        if (!node) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        }

        if (_nodes.count(node) == 0) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : node is not attached.");
        }

        disconnect_node_with_predicate([&node](connection const &connection) {
            return (connection.destination_node() == node || connection.source_node() == node);
        });

        remove_node_from_graph(node);

        node.manageable().set_manager(manager{nullptr});

        _nodes.erase(node);
    }

    void detach_node_if_unused(audio::engine::node &node) {
        auto filtered_connection = filter(_connections, [node](auto const &connection) {
            return (connection.destination_node() == node || connection.source_node() == node);
        });

        if (filtered_connection.size() == 0) {
            detach_node(node);
        }
    }

    bool prepare_graph() {
        if (_graph) {
            return true;
        }

        _graph = audio::graph{};

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        if (device_io()) {
            auto &manageable_device_io = device_io().manageable();
            manageable_device_io.add_device_io();
            _graph.add_audio_device_io(manageable_device_io.device_io());
        }
#endif

        for (auto &node : _nodes) {
            add_node_to_graph(node);
        }

        for (auto &connection : _connections) {
            if (!add_connection(connection)) {
                return false;
            }
        }

        update_all_node_connections();

        return true;
    }

    audio::engine::connection connect(audio::engine::node &src_node, audio::engine::node &dst_node,
                                      uint32_t const src_bus_idx, uint32_t const dst_bus_idx,
                                      const audio::format &format) {
        if (!src_node || !dst_node) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        }

        if (!src_node.is_available_output_bus(src_bus_idx)) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : output bus(" +
                                        std::to_string(src_bus_idx) + ") is not available.");
        }

        if (!dst_node.is_available_input_bus(dst_bus_idx)) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : input bus(" +
                                        std::to_string(dst_bus_idx) + ") is not available.");
        }

        if (!node_exists(src_node)) {
            attach_node(src_node);
        }

        if (!node_exists(dst_node)) {
            attach_node(dst_node);
        }

        connection_for_engine connection(src_node, src_bus_idx, dst_node, dst_bus_idx, format);

        _connections.insert(connection);

        if (_graph) {
            add_connection(connection);
            update_node_connections(src_node);
            update_node_connections(dst_node);
        }

        return connection;
    }

    void disconnect(audio::engine::connection &connection) {
        std::vector<node> update_nodes{connection.source_node(), connection.destination_node()};

        remove_connection_from_nodes(connection);
        connection.node_removable().remove_nodes();

        for (auto &node : update_nodes) {
            node.manageable().update_connections();
            detach_node_if_unused(node);
        }

        _connections.erase(connection);
    }

    void disconnect(audio::engine::node &node) {
        if (node_exists(node)) {
            detach_node(node);
        }
    }

    void disconnect_node_with_predicate(std::function<bool(connection const &)> predicate) {
        auto connections = filter(_connections, [&predicate](auto const &connection) { return predicate(connection); });

        std::unordered_set<node> update_nodes;

        for (auto connection : connections) {
            update_nodes.insert(connection.source_node());
            update_nodes.insert(connection.destination_node());
            remove_connection_from_nodes(connection);
            connection.node_removable().remove_nodes();
        }

        for (auto node : update_nodes) {
            node.manageable().update_connections();
            detach_node_if_unused(node);
        }

        for (auto &connection : connections) {
            _connections.erase(connection);
        }
    }

    void add_node_to_graph(audio::engine::node const &node) {
        if (!_graph) {
            return;
        }

        if (auto const &handler = node.manageable().add_to_graph_handler()) {
            handler(_graph);
        }
    }

    void remove_node_from_graph(audio::engine::node const &node) {
        if (!_graph) {
            return;
        }

        if (auto const &handler = node.manageable().remove_from_graph_handler()) {
            handler(_graph);
        }
    }

    bool add_connection(audio::engine::connection const &connection) {
        if (!connection) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
            return false;
        }

        auto destination_node = connection.destination_node();
        auto source_node = connection.source_node();

        if (_nodes.count(destination_node) == 0 || _nodes.count(source_node) == 0) {
            throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : node is not attached.");
            return false;
        }

        destination_node.connectable().add_connection(connection);
        source_node.connectable().add_connection(connection);

        return true;
    }

    void remove_connection_from_nodes(audio::engine::connection const &connection) {
        if (!connection) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
            return;
        }

        if (auto source_node = connection.source_node()) {
            source_node.connectable().remove_connection(connection);
        }

        if (auto destination_node = connection.destination_node()) {
            destination_node.connectable().remove_connection(connection);
        }
    }

    void update_node_connections(audio::engine::node &node) {
        if (!_graph) {
            return;
        }

        node.manageable().update_connections();
    }

    void update_all_node_connections() {
        if (!_graph) {
            return;
        }

        for (auto node : _nodes) {
            node.manageable().update_connections();
        }
    }

    std::unordered_set<node> &nodes() {
        return _nodes;
    }

    audio::engine::connection_set &connections() {
        return _connections;
    }

    audio::engine::connection_set input_connections_for_destination_node(audio::engine::node const &node) {
        return filter(_connections, [&node](auto const &connection) { return connection.destination_node() == node; });
    }

    audio::engine::connection_set output_connections_for_source_node(audio::engine::node const &node) {
        return filter(_connections, [&node](auto const &connection) { return connection.source_node() == node; });
    }

    void reload_graph() {
        if (auto prev_graph = graph()) {
            bool const prev_runnging = prev_graph.is_running();

            prev_graph.stop();

            for (auto &node : _nodes) {
                remove_node_from_graph(node);
            }

            _graph = nullptr;

            if (!prepare_graph()) {
                return;
            }

            if (prev_runnging) {
                graph().start();
            }
        }
    }

    audio::engine::manager::add_result_t add_offline_output() {
        if (_offline_output) {
            return add_result_t{add_error_t::already_added};
        } else {
            _offline_output = audio::engine::offline_output{};
            return add_result_t{nullptr};
        }
    }

    audio::engine::manager::remove_result_t remove_offline_output() {
        if (_offline_output) {
            _offline_output = nullptr;
            return remove_result_t{nullptr};
        } else {
            return remove_result_t{remove_error_t::already_removed};
        }
    }

    audio::engine::offline_output &offline_output() {
        return _offline_output;
    }

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    void set_device_io(audio::engine::device_io &&node) {
        if (node) {
            _device_io = std::move(node);

            if (_graph) {
                auto &manageable_device_io = _device_io.manageable();
                manageable_device_io.add_device_io();
                _graph.add_audio_device_io(manageable_device_io.device_io());
            }
        } else {
            if (_device_io) {
                auto &manageable_node = _device_io.manageable();
                if (_graph) {
                    if (auto &device_io = manageable_node.device_io()) {
                        _graph.remove_audio_device_io(device_io);
                    }
                }

                manageable_node.remove_device_io();
                _device_io = nullptr;
            }
        }
    }

    audio::engine::device_io &device_io() {
        return _device_io;
    }

#endif

    audio::engine::manager::start_result_t start_render() {
        if (auto const graph = _graph) {
            if (graph.is_running()) {
                return start_result_t(start_error_t::already_running);
            }
        }

        if (auto const offline_output = _offline_output) {
            if (offline_output.is_running()) {
                return start_result_t(start_error_t::already_running);
            }
        }

        if (!prepare_graph()) {
            return start_result_t(start_error_t::prepare_failure);
        }

        _graph.start();

        return start_result_t(nullptr);
    }

    audio::engine::manager::start_result_t start_offline_render(offline_render_f &&render_handler,
                                                                offline_completion_f &&completion_handler) {
        if (auto const graph = _graph) {
            if (graph.is_running()) {
                return start_result_t(start_error_t::already_running);
            }
        }

        if (auto const offline_output = _offline_output) {
            if (offline_output.is_running()) {
                return start_result_t(start_error_t::already_running);
            }
        }

        if (!prepare_graph()) {
            return start_result_t(start_error_t::prepare_failure);
        }

        auto offline_output = _offline_output;

        if (!offline_output) {
            return start_result_t(start_error_t::offline_output_not_found);
        }

        auto &node = offline_output.manageable();
        auto result = node.start(std::move(render_handler), std::move(completion_handler));

        if (result) {
            return start_result_t(nullptr);
        } else {
            return start_result_t(start_error_t::offline_output_starting_failure);
        }
    }

    void stop() {
        if (auto graph = _graph) {
            graph.stop();
        }

        if (auto offline_output = _offline_output) {
            offline_output.manageable().stop();
        }
    }

    void post_configuration_change() {
        _subject.notify(method::configuration_change, _weak_manager.lock());
    }

   private:
    objc_ptr<id> _reset_observer;
    objc_ptr<id> _route_change_observer;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    audio::engine::device_io _device_io = nullptr;
    audio::device::observer_t _device_observer;
#endif

    audio::graph _graph = nullptr;
    std::unordered_set<node> _nodes;
    audio::engine::connection_set _connections;
    audio::engine::offline_output _offline_output = nullptr;
};

#pragma mark - audio::engine::manager

audio::engine::manager::manager() : base(std::make_shared<impl>()) {
    impl_ptr<impl>()->prepare(*this);
}

audio::engine::manager::manager(std::nullptr_t) : base(nullptr) {
}

audio::engine::manager::~manager() = default;

audio::engine::connection audio::engine::manager::connect(node &source_node, node &destination_node,
                                                          audio::format const &format) {
    if (!source_node || !destination_node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    auto source_bus_result = source_node.next_available_output_bus();
    auto destination_bus_result = destination_node.next_available_input_bus();

    if (!source_bus_result || !destination_bus_result) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : bus is not available.");
    }

    return connect(source_node, destination_node, *source_bus_result, *destination_bus_result, format);
}

audio::engine::connection audio::engine::manager::connect(node &source_node, node &destination_node,
                                                          uint32_t const src_bus_idx, uint32_t const dst_bus_idx,
                                                          audio::format const &format) {
    return impl_ptr<impl>()->connect(source_node, destination_node, src_bus_idx, dst_bus_idx, format);
}

void audio::engine::manager::disconnect(connection &connection) {
    impl_ptr<impl>()->disconnect(connection);
}

void audio::engine::manager::disconnect(node &node) {
    impl_ptr<impl>()->disconnect(node);
}

void audio::engine::manager::disconnect_input(node const &node) {
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    impl_ptr<impl>()->disconnect_node_with_predicate(
        [node](connection const &connection) { return (connection.destination_node() == node); });
}

void audio::engine::manager::disconnect_input(node const &node, uint32_t const bus_idx) {
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    impl_ptr<impl>()->disconnect_node_with_predicate([node, bus_idx](auto const &connection) {
        return (connection.destination_node() == node && connection.destination_bus() == bus_idx);
    });
}

void audio::engine::manager::disconnect_output(node const &node) {
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    impl_ptr<impl>()->disconnect_node_with_predicate(
        [node](connection const &connection) { return (connection.source_node() == node); });
}

void audio::engine::manager::disconnect_output(node const &node, uint32_t const bus_idx) {
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    impl_ptr<impl>()->disconnect_node_with_predicate([node, bus_idx](auto const &connection) {
        return (connection.source_node() == node && connection.source_bus() == bus_idx);
    });
}

audio::engine::manager::add_result_t audio::engine::manager::add_offline_output() {
    return impl_ptr<impl>()->add_offline_output();
}

audio::engine::manager::remove_result_t audio::engine::manager::remove_offline_output() {
    return impl_ptr<impl>()->remove_offline_output();
}

audio::engine::offline_output const &audio::engine::manager::offline_output() const {
    return impl_ptr<impl>()->offline_output();
}

audio::engine::offline_output &audio::engine::manager::offline_output() {
    return impl_ptr<impl>()->offline_output();
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

audio::engine::manager::add_result_t audio::engine::manager::add_device_io() {
    if (impl_ptr<impl>()->device_io()) {
        return add_result_t{add_error_t::already_added};
    } else {
        impl_ptr<impl>()->set_device_io(audio::engine::device_io{});
        return add_result_t{nullptr};
    }
}

audio::engine::manager::remove_result_t audio::engine::manager::remove_device_io() {
    if (impl_ptr<impl>()->device_io()) {
        impl_ptr<impl>()->set_device_io(nullptr);
        return remove_result_t{nullptr};
    } else {
        return remove_result_t{remove_error_t::already_removed};
    }
}

audio::engine::device_io const &audio::engine::manager::device_io() const {
    return impl_ptr<impl>()->device_io();
}

audio::engine::device_io &audio::engine::manager::device_io() {
    return impl_ptr<impl>()->device_io();
}

#endif

audio::engine::manager::start_result_t audio::engine::manager::start_render() {
    return impl_ptr<impl>()->start_render();
}

audio::engine::manager::start_result_t audio::engine::manager::start_offline_render(
    offline_render_f render_handler, offline_completion_f completion_handler) {
    return impl_ptr<impl>()->start_offline_render(std::move(render_handler), std::move(completion_handler));
}

void audio::engine::manager::stop() {
    impl_ptr<impl>()->stop();
}

audio::engine::manager::subject_t &audio::engine::manager::subject() const {
    return impl_ptr<impl>()->_subject;
}

#if YAS_TEST

std::unordered_set<audio::engine::node> &audio::engine::manager::nodes() const {
    return impl_ptr<impl>()->nodes();
}

audio::engine::connection_set &audio::engine::manager::connections() const {
    return impl_ptr<impl>()->connections();
}

#endif

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
