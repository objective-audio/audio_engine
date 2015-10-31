//
//  yas_audio_engine_impl.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_engine_impl.h"

#include "yas_audio_node.h"
#include "yas_audio_unit_node.h"
#include "yas_audio_device_io_node.h"
#include "yas_audio_offline_output_node.h"
#include "yas_audio_graph.h"
#include "yas_stl_utils.h"
#include "yas_any.h"
#include <CoreFoundation/CoreFoundation.h>
#include <AVFoundation/AVFoundation.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
#include "yas_audio_device.h"
#endif

using namespace yas;

class audio_engine::impl::core
{
   public:
    ~core()
    {
#if TARGET_OS_IPHONE
        if (reset_observer) {
            [[NSNotificationCenter defaultCenter] removeObserver:reset_observer.object()];
        }
        if (route_change_observer) {
            [[NSNotificationCenter defaultCenter] removeObserver:route_change_observer.object()];
        }
#endif
    }

    base_weak<audio_engine> weak_engine;
    objc::container<> reset_observer;
    objc::container<> route_change_observer;
    yas::subject subject;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    observer device_observer;
#endif

    audio_graph graph = nullptr;
    std::unordered_map<uintptr_t, audio_node> nodes;
    audio_connection_map connections;
    audio_offline_output_node offline_output_node = nullptr;
};

audio_engine::impl::impl() : base::impl(), _core(std::make_unique<core>())
{
}

audio_engine::impl::~impl() = default;

void audio_engine::impl::prepare(const audio_engine &engine)
{
    _core->weak_engine = engine;

#if TARGET_OS_IPHONE
    auto reset_lambda = [weak_engine = _core->weak_engine](NSNotification * note)
    {
        if (auto engine = weak_engine.lock()) {
            engine._impl_ptr()->reload_graph();
        }
    };

    id reset_observer =
        [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionMediaServicesWereResetNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:reset_lambda];
    _core->reset_observer.set_object(reset_observer);

    auto route_change_lambda = [weak_engine = _core->weak_engine](NSNotification * note)
    {
        if (auto engine = weak_engine.lock()) {
            engine._impl_ptr()->post_configuration_change();
        }
    };

    id route_change_observer =
        [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionRouteChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:route_change_lambda];
    _core->route_change_observer.set_object(route_change_observer);

#elif TARGET_OS_MAC
    _core->device_observer.add_handler(audio_device::system_subject(), audio_device_method::configuration_change,
                                       [weak_engine = _core->weak_engine](const auto &method, const auto &infos) {
                                           if (auto engine = weak_engine.lock()) {
                                               engine._impl_ptr()->post_configuration_change();
                                           }
                                       });
#endif
}

base_weak<audio_engine> &audio_engine::impl::weak_engine() const
{
    return _core->weak_engine;
}

objc::container<> &audio_engine::impl::reset_observer() const
{
    return _core->reset_observer;
}

objc::container<> &audio_engine::impl::route_change_observer() const
{
    return _core->route_change_observer;
}

yas::subject &audio_engine::impl::subject() const
{
    return _core->subject;
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
observer &audio_engine::impl::device_observer()
{
    return _core->device_observer;
}
#endif

bool audio_engine::impl::node_exists(const audio_node &node)
{
    return _core->nodes.count(node.key()) > 0;
}

void audio_engine::impl::attach_node(audio_node &node)
{
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    if (_core->nodes.count(node.key()) > 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : node is already attached.");
    }

    _core->nodes.insert(std::make_pair(node.key(), node));
    audio_node::private_access::set_engine(node, _core->weak_engine.lock());

    add_node_to_graph(node);
}

void audio_engine::impl::detach_node(audio_node &node)
{
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    if (_core->nodes.count(node.key()) == 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : node is not attached.");
    }

    disconnect_node_with_predicate([&node](const audio_connection &connection) {
        return (connection.destination_node() == node || connection.source_node() == node);
    });

    remove_node_from_graph(node);
    audio_node::private_access::set_engine(node, audio_engine(nullptr));
    _core->nodes.erase(node.key());
}

void audio_engine::impl::detach_node_if_unused(audio_node &node)
{
    auto filtered_connection = filter(_core->connections, [node](const auto &pair) {
        const auto &connection = pair.second;
        return (connection.destination_node() == node || connection.source_node() == node);
    });

    if (filtered_connection.size() == 0) {
        detach_node(node);
    }
}

bool audio_engine::impl::prepare()
{
    if (_core->graph) {
        return true;
    }

    _core->graph.prepare();

    for (auto &pair : _core->nodes) {
        add_node_to_graph(pair.second);
    }

    for (auto &pair : _core->connections) {
        auto &connection = pair.second;
        if (!add_connection(connection)) {
            return false;
        }
    }

    update_all_node_connections();

    return true;
}

audio_connection audio_engine::impl::connect(audio_node &source_node, audio_node &destination_node,
                                             const UInt32 source_bus_idx, const UInt32 destination_bus_idx,
                                             const audio_format &format)
{
    if (!source_node || !destination_node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    if (!source_node.is_available_output_bus(source_bus_idx)) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : output bus(" +
                                    std::to_string(source_bus_idx) + ") is not available.");
    }

    if (!destination_node.is_available_input_bus(destination_bus_idx)) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : input bus(" +
                                    std::to_string(destination_bus_idx) + ") is not available.");
    }

    if (!node_exists(source_node)) {
        attach_node(source_node);
    }

    if (!node_exists(destination_node)) {
        attach_node(destination_node);
    }

    auto connection = audio_connection::private_access::create(source_node, source_bus_idx, destination_node,
                                                               destination_bus_idx, format);

    connections().insert(std::make_pair(connection.key(), connection));

    if (graph()) {
        add_connection(connection);
        update_node_connections(source_node);
        update_node_connections(destination_node);
    }

    return connection;
}

void audio_engine::impl::disconnect(audio_connection &connection)
{
    std::vector<audio_node> update_nodes{connection.source_node(), connection.destination_node()};

    remove_connection_from_nodes(connection);
    audio_connection::private_access::remove_nodes(connection);

    for (auto &node : update_nodes) {
        audio_node::private_access::update_connections(node);
        detach_node_if_unused(node);
    }

    connections().erase(connection.key());
}

void audio_engine::impl::disconnect(audio_node &node)
{
    if (node_exists(node)) {
        detach_node(node);
    }
}

void audio_engine::impl::disconnect_node_with_predicate(std::function<bool(const audio_connection &)> predicate)
{
    auto remove_connections =
        filter(_core->connections, [&predicate](const auto &pair) { return predicate(pair.second); });
    std::map<uintptr_t, audio_node> update_nodes;

    for (auto &pair : remove_connections) {
        auto &connection = pair.second;
        update_nodes.insert(std::make_pair(connection.source_node().key(), connection.source_node()));
        update_nodes.insert(std::make_pair(connection.destination_node().key(), connection.destination_node()));
        remove_connection_from_nodes(connection);
        audio_connection::private_access::remove_nodes(connection);
    }

    for (auto &pair : update_nodes) {
        auto &node = pair.second;
        audio_node::private_access::update_connections(node);
        detach_node_if_unused(node);
    }

    for (auto &pair : remove_connections) {
        auto &connection = pair.second;
        _core->connections.erase(connection.key());
    }
}

void audio_engine::impl::add_node_to_graph(audio_node &node)
{
    if (!_core->graph) {
        return;
    }

    if (auto unit_node = node.cast<audio_unit_node>()) {
        yas::audio_unit_node::private_access::add_audio_unit_to_graph(unit_node, _core->graph);
    }

#if (!TARGET_OS_IPHONE & TARGET_OS_MAC)
    if (auto device_io_node = node.cast<audio_device_io_node>()) {
        audio_device_io_node::private_access::add_audio_device_io_to_graph(device_io_node, _core->graph);
    }
#endif

    if (auto offline_output_node = node.cast<audio_offline_output_node>()) {
        if (_core->offline_output_node) {
            throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : offline_output_node is already attached.");
        } else {
            _core->offline_output_node = offline_output_node;
        }
    }
}

void audio_engine::impl::remove_node_from_graph(const audio_node &node)
{
    if (!_core->graph) {
        return;
    }

    if (auto unit_node = node.cast<audio_unit_node>()) {
        yas::audio_unit_node::private_access::remove_audio_unit_from_graph(unit_node);
    }

#if (!TARGET_OS_IPHONE & TARGET_OS_MAC)
    if (auto device_io_node = node.cast<audio_device_io_node>()) {
        audio_device_io_node::private_access::remove_audio_device_io_from_graph(device_io_node);
    }
#endif

    if (auto offline_output_node = node.cast<audio_offline_output_node>()) {
        if (offline_output_node == _core->offline_output_node) {
            _core->offline_output_node = nullptr;
        }
    }
}

bool audio_engine::impl::add_connection(const audio_connection &connection)
{
    if (!connection) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        return false;
    }

    auto destination_node = connection.destination_node();
    auto source_node = connection.source_node();

    if (_core->nodes.count(destination_node.key()) == 0 || _core->nodes.count(source_node.key()) == 0) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : node is not attached.");
        return false;
    }

    audio_node::private_access::add_connection(destination_node, connection);
    audio_node::private_access::add_connection(source_node, connection);

    return true;
}

void audio_engine::impl::remove_connection_from_nodes(const audio_connection &connection)
{
    if (!connection) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        return;
    }

    if (auto source_node = connection.source_node()) {
        audio_node::private_access::remove_connection(source_node, connection);
    }

    if (auto destination_node = connection.destination_node()) {
        audio_node::private_access::remove_connection(destination_node, connection);
    }
}

void audio_engine::impl::update_node_connections(audio_node &node)
{
    if (!_core->graph) {
        return;
    }

    audio_node::private_access::update_connections(node);
}

void audio_engine::impl::update_all_node_connections()
{
    if (!_core->graph) {
        return;
    }

    for (auto &pair : _core->nodes) {
        audio_node::private_access::update_connections(pair.second);
    }
}

audio_connection_map audio_engine::impl::input_connections_for_destination_node(const audio_node &node) const
{
    return filter(_core->connections, [node](const auto &pair) { return pair.second.destination_node() == node; });
}

audio_connection_map audio_engine::impl::output_connections_for_source_node(const audio_node &node) const
{
    return filter(_core->connections, [node](const auto &pair) { return pair.second.source_node() == node; });
}

void audio_engine::impl::set_graph(const audio_graph &graph)
{
    _core->graph = graph;
}

audio_graph audio_engine::impl::graph() const
{
    return _core->graph;
}

void audio_engine::impl::reload_graph()
{
    if (auto prev_graph = graph()) {
        const bool prev_runnging = prev_graph.is_running();

        prev_graph.stop();

        for (auto &pair : nodes()) {
            remove_node_from_graph(pair.second);
        }

        set_graph(nullptr);

        if (!prepare()) {
            return;
        }

        if (prev_runnging) {
            graph().start();
        }
    }
}

std::unordered_map<uintptr_t, audio_node> &audio_engine::impl::nodes() const
{
    return _core->nodes;
}

audio_connection_map &audio_engine::impl::connections() const
{
    return _core->connections;
}

audio_offline_output_node &audio_engine::impl::offline_output_node() const
{
    return _core->offline_output_node;
}

audio_engine::start_result_t audio_engine::impl::start_render()
{
    if (const auto graph = _core->graph) {
        if (graph.is_running()) {
            return start_result_t(start_error_t::already_running);
        }
    }

    if (const auto offline_output_node = _core->offline_output_node) {
        if (offline_output_node.is_running()) {
            return start_result_t(start_error_t::already_running);
        }
    }

    if (!prepare()) {
        return start_result_t(start_error_t::prepare_failure);
    }

    graph().start();

    return start_result_t(nullptr);
}

audio_engine::start_result_t audio_engine::impl::start_offline_render(const offline_render_f &render_function,
                                                                      const offline_completion_f &completion_function)
{
    if (const auto graph = _core->graph) {
        if (graph.is_running()) {
            return start_result_t(start_error_t::already_running);
        }
    }

    if (const auto offline_output_node = _core->offline_output_node) {
        if (offline_output_node.is_running()) {
            return start_result_t(start_error_t::already_running);
        }
    }

    if (!prepare()) {
        return start_result_t(start_error_t::prepare_failure);
    }

    auto offline_output_node = _core->offline_output_node;

    if (!offline_output_node) {
        return start_result_t(start_error_t::offline_output_not_found);
    }

    auto result =
        audio_offline_output_node::private_access::start(offline_output_node, render_function, completion_function);

    if (result) {
        return start_result_t(nullptr);
    } else {
        return start_result_t(start_error_t::offline_output_starting_failure);
    }
}

void audio_engine::impl::stop()
{
    if (auto graph = _core->graph) {
        graph.stop();
    }

    if (auto offline_output_node = _core->offline_output_node) {
        audio_offline_output_node::private_access::stop(offline_output_node);
    }
}

void audio_engine::impl::post_configuration_change() const
{
    subject().notify(audio_engine_method::configuration_change);
}
