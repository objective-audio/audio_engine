//
//  yas_audio_engine.mm
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_engine.h"
#include "yas_audio_node.h"
#include "yas_audio_unit_node.h"
#include "yas_audio_device_io_node.h"
#include "yas_audio_graph.h"
#include "yas_stl_utils.h"
#include "yas_objc_container.h"
#include "yas_any.h"
#include <set>
#include <CoreFoundation/CoreFoundation.h>
#include <AVFoundation/AVFoundation.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
#include "yas_audio_device.h"
#endif

using namespace yas;

class audio_engine::impl
{
   public:
    std::weak_ptr<audio_engine> engine;
    objc_strong_container reset_observer;
    objc_strong_container route_change_observer;
    yas::subject subject;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    observer device_observer;
#endif

    impl() : reset_observer(), route_change_observer(), subject()
    {
    }

    bool node_exists(const audio_node_sptr &node)
    {
        return _nodes.count(node) > 0;
    }

    void attach_node(const audio_node_sptr &node)
    {
        if (!node) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        }

        if (_nodes.count(node) > 0) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : node is already attached.");
        }

        _nodes.insert(node);
        audio_node::private_access::set_engine(node, engine.lock());

        add_node_to_graph(node);
    }

    void detach_node(const audio_node_sptr &node)
    {
        if (!node) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        }

        if (_nodes.count(node) == 0) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : node is not attached.");
        }

        disconnect_node_with_predicate([node](const audio_connection_sptr &connection) {
            return (connection->destination_node() == node || connection->source_node() == node);
        });

        remove_node_from_graph(node);
        audio_node::private_access::set_engine(node, nullptr);
        _nodes.erase(node);
    }

    void detach_node_if_unused(const audio_node_sptr &node)
    {
        auto filtered_set = filter(_connections, [node](const audio_connection_sptr &connection) {
            return (connection->destination_node() == node || connection->source_node() == node);
        });

        if (filtered_set.size() == 0) {
            detach_node(node);
        }
    }

    bool prepare()
    {
        if (_graph) {
            return true;
        }

        _graph.prepare();

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

    void disconnect_node_with_predicate(std::function<bool(const audio_connection_sptr &)> predicate)
    {
        auto remove_connections = filter(_connections, predicate);
        std::set<audio_node_sptr> update_nodes;

        for (auto &connection : remove_connections) {
            update_nodes.insert(connection->source_node());
            update_nodes.insert(connection->destination_node());
            remove_connection_from_nodes(connection);
            audio_connection::private_access::remove_nodes(connection);
        }

        for (auto &node : update_nodes) {
            audio_node::private_access::update_connections(node);
            detach_node_if_unused(node);
        }

        for (auto &connection : remove_connections) {
            _connections.erase(connection);
        }
    }

    void add_node_to_graph(const audio_node_sptr &node)
    {
        if (!_graph) {
            return;
        }

        if (auto unit_node = dynamic_cast<audio_unit_node *>(node.get())) {
            yas::audio_unit_node::private_access::add_audio_unit_to_graph(unit_node, _graph);
        }

#if (!TARGET_OS_IPHONE & TARGET_OS_MAC)
        if (auto device_io_node = dynamic_cast<audio_device_io_node *>(node.get())) {
            audio_device_io_node::private_access::add_audio_device_io_to_graph(device_io_node, _graph);
        }
#endif

        if (dynamic_cast<class audio_offline_output_node *>(node.get())) {
            if (_offline_output_node) {
                throw std::runtime_error(std::string(__PRETTY_FUNCTION__) +
                                         " : offline_output_node is already attached.");
            } else {
                _offline_output_node = node;
            }
        }
    }

    void remove_node_from_graph(const audio_node_sptr &node)
    {
        if (!_graph) {
            return;
        }

        if (audio_unit_node *unit_node = dynamic_cast<class audio_unit_node *>(node.get())) {
            yas::audio_unit_node::private_access::remove_audio_unit_from_graph(unit_node);
        }

#if (!TARGET_OS_IPHONE & TARGET_OS_MAC)
        if (auto device_io_node = dynamic_cast<audio_device_io_node *>(node.get())) {
            audio_device_io_node::private_access::remove_audio_device_io_from_graph(device_io_node);
        }
#endif

        if (auto *offline_output_node = dynamic_cast<class audio_offline_output_node *>(node.get())) {
            if (offline_output_node == _offline_output_node.get()) {
                _offline_output_node = nullptr;
            }
        }
    }

    bool add_connection(const audio_connection_sptr &connection)
    {
        if (!connection) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
            return false;
        }

        auto destination_node = connection->destination_node();
        auto source_node = connection->source_node();

        if (_nodes.count(destination_node) == 0 || _nodes.count(source_node) == 0) {
            throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : node is not attached.");
            return false;
        }

        audio_node::private_access::add_connection(destination_node, connection);
        audio_node::private_access::add_connection(source_node, connection);

        return true;
    }

    void remove_connection_from_nodes(const audio_connection_sptr &connection)
    {
        if (!connection) {
            throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
            return;
        }

        if (auto source_node = connection->source_node()) {
            audio_node::private_access::remove_connection(source_node, *connection);
        }

        if (auto destination_node = connection->destination_node()) {
            audio_node::private_access::remove_connection(destination_node, *connection);
        }
    }

    void update_node_connections(const audio_node_sptr &node)
    {
        if (!_graph) {
            return;
        }

        audio_node::private_access::update_connections(node);
    }

    void update_all_node_connections()
    {
        if (!_graph) {
            return;
        }

        for (auto &node : _nodes) {
            audio_node::private_access::update_connections(node);
        }
    }

    std::set<audio_connection_sptr> input_connections_for_destination_node(const audio_node_sptr &node)
    {
        return filter(_connections, [node](const audio_connection_sptr &connection) {
            return connection->destination_node() == node;
        });
    }

    std::set<audio_connection_sptr> output_connections_for_source_node(const audio_node_sptr &node)
    {
        return filter(_connections,
                      [node](const audio_connection_sptr &connection) { return connection->source_node() == node; });
    }

    void set_graph(const audio_graph &graph)
    {
        _graph = graph;
    }

    audio_graph graph()
    {
        return _graph;
    }

    std::set<audio_node_sptr> &nodes()
    {
        return _nodes;
    }

    std::set<audio_connection_sptr> &connections()
    {
        return _connections;
    }

    audio_offline_output_node *offline_output_node()
    {
        return dynamic_cast<audio_offline_output_node *>(_offline_output_node.get());
    }

   private:
    audio_graph _graph;
    std::set<audio_node_sptr> _nodes;
    std::set<audio_connection_sptr> _connections;
    audio_node_sptr _offline_output_node;
};

audio_engine_sptr audio_engine::create()
{
    auto engine = audio_engine_sptr(new audio_engine());
    engine->_impl->engine = engine;

    std::weak_ptr<audio_engine> weak_engine = engine;

#if TARGET_OS_IPHONE
    auto reset_lambda = [weak_engine](NSNotification *note) {
        if (auto engine = weak_engine.lock()) {
            engine->_reload_graph();
        }
    };

    id reset_observer =
        [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionMediaServicesWereResetNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:reset_lambda];
    engine->_impl->reset_observer.set_object(reset_observer);

    auto route_change_lambda = [weak_engine](NSNotification *note) {
        if (auto engine = weak_engine.lock()) {
            engine->_post_configuration_change();
        }
    };

    id route_change_observer =
        [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionRouteChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:route_change_lambda];
    engine->_impl->route_change_observer.set_object(route_change_observer);

#elif TARGET_OS_MAC
    engine->_impl->device_observer.add_handler(audio_device::system_subject(),
                                               audio_device_method::configuration_change,
                                               [weak_engine](const auto &method, const auto &infos) {
                                                   if (auto engine = weak_engine.lock()) {
                                                       engine->_post_configuration_change();
                                                   }
                                               });
#endif

    return engine;
}

audio_engine::audio_engine() : _impl(std::make_unique<impl>())
{
}

audio_engine::~audio_engine()
{
#if TARGET_OS_IPHONE
    if (auto reset_observer = _impl->reset_observer) {
        [[NSNotificationCenter defaultCenter] removeObserver:reset_observer.object()];
    }

    if (auto route_change_observer = _impl->route_change_observer) {
        [[NSNotificationCenter defaultCenter] removeObserver:route_change_observer.object()];
    }
#endif
}

audio_connection_sptr audio_engine::connect(const audio_node_sptr &source_node, const audio_node_sptr &destination_node,
                                            const audio_format &format)
{
    if (!source_node || !destination_node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    auto source_bus_result = source_node->next_available_output_bus();
    auto destination_bus_result = destination_node->next_available_input_bus();

    if (!source_bus_result || !destination_bus_result) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : bus is not available.");
    }

    return connect(source_node, destination_node, *source_bus_result, *destination_bus_result, format);
}

audio_connection_sptr audio_engine::connect(const audio_node_sptr &source_node, const audio_node_sptr &destination_node,
                                            const UInt32 source_bus_idx, const UInt32 destination_bus_idx,
                                            const audio_format &format)
{
    if (!source_node || !destination_node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    if (!source_node->is_available_output_bus(source_bus_idx)) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : output bus(" +
                                    std::to_string(source_bus_idx) + ") is not available.");
    }

    if (!destination_node->is_available_input_bus(destination_bus_idx)) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : input bus(" +
                                    std::to_string(destination_bus_idx) + ") is not available.");
    }

    if (!_impl->node_exists(source_node)) {
        _impl->attach_node(source_node);
    }

    if (!_impl->node_exists(destination_node)) {
        _impl->attach_node(destination_node);
    }

    auto connection = audio_connection::private_access::create(source_node, source_bus_idx, destination_node,
                                                               destination_bus_idx, format);

    auto &connections = _impl->connections();
    connections.insert(connection);

    if (_impl->graph()) {
        _impl->add_connection(connection);
        _impl->update_node_connections(source_node);
        _impl->update_node_connections(destination_node);
    }

    return connection;
}

void audio_engine::disconnect(const audio_connection_sptr &connection)
{
    auto update_nodes = {connection->source_node(), connection->destination_node()};

    _impl->remove_connection_from_nodes(connection);
    audio_connection::private_access::remove_nodes(connection);

    for (auto &node : update_nodes) {
        audio_node::private_access::update_connections(node);
        _impl->detach_node_if_unused(node);
    }

    _impl->connections().erase(connection);
}

void audio_engine::disconnect(const audio_node_sptr &node)
{
    if (_impl->node_exists(node)) {
        _impl->detach_node(node);
    }
}

void audio_engine::disconnect_input(const audio_node_sptr &node)
{
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    _impl->disconnect_node_with_predicate(
        [node](const audio_connection_sptr &connection) { return (connection->destination_node() == node); });
}

void audio_engine::disconnect_input(const audio_node_sptr &node, const UInt32 bus_idx)
{
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    _impl->disconnect_node_with_predicate([node, bus_idx](const audio_connection_sptr &connection) {
        return (connection->destination_node() == node && connection->destination_bus() == bus_idx);
    });
}

void audio_engine::disconnect_output(const audio_node_sptr &node)
{
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    _impl->disconnect_node_with_predicate(
        [node](const audio_connection_sptr &connection) { return (connection->source_node() == node); });
}

void audio_engine::disconnect_output(const audio_node_sptr &node, const UInt32 bus_idx)
{
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    _impl->disconnect_node_with_predicate([node, bus_idx](const audio_connection_sptr &connection) {
        return (connection->source_node() == node && connection->source_bus() == bus_idx);
    });
}

audio_engine::start_result_t audio_engine::start_render()
{
    if (const auto graph = _impl->graph()) {
        if (graph.is_running()) {
            return start_result_t(start_error_t::already_running);
        }
    }

    if (const auto offline_output_node = _impl->offline_output_node()) {
        if (offline_output_node->is_running()) {
            return start_result_t(start_error_t::already_running);
        }
    }

    if (!_impl->prepare()) {
        return start_result_t(start_error_t::prepare_failure);
    }

    _impl->graph().start();

    return start_result_t(nullptr);
}

audio_engine::start_result_t audio_engine::start_offline_render(const offline_render_f &render_function,
                                                                const offline_completion_f &completion_function)
{
    if (const auto graph = _impl->graph()) {
        if (graph.is_running()) {
            return start_result_t(start_error_t::already_running);
        }
    }

    if (const auto offline_output_node = _impl->offline_output_node()) {
        if (offline_output_node->is_running()) {
            return start_result_t(start_error_t::already_running);
        }
    }

    if (!_impl->prepare()) {
        return start_result_t(start_error_t::prepare_failure);
    }

    const auto offline_output_node = _impl->offline_output_node();

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

void audio_engine::stop()
{
    if (auto graph = _impl->graph()) {
        graph.stop();
    }

    if (auto offline_output_node = _impl->offline_output_node()) {
        audio_offline_output_node::private_access::stop(offline_output_node);
    }
}

subject &audio_engine::subject() const
{
    return _impl->subject;
}

void audio_engine::_reload_graph()
{
    if (auto prev_graph = _impl->graph()) {
        const bool prev_runnging = prev_graph.is_running();

        prev_graph.stop();

        auto &nodes = _impl->nodes();
        for (auto &node : nodes) {
            _impl->remove_node_from_graph(node);
        }

        _impl->set_graph(nullptr);

        if (!_impl->prepare()) {
            return;
        }

        if (prev_runnging) {
            _impl->graph().start();
        }
    }
}

void audio_engine::_post_configuration_change() const
{
    _impl->subject.notify(audio_engine_method::configuration_change);
}

std::set<audio_node_sptr> &audio_engine::_nodes() const
{
    return _impl->nodes();
}

std::set<audio_connection_sptr> &audio_engine::_connections() const
{
    return _impl->connections();
}

std::string yas::to_string(const audio_engine::start_error_t &error)
{
    switch (error) {
        case audio_engine::start_error_t::already_running:
            return "already_running";
        case audio_engine::start_error_t::prepare_failure:
            return "prepare_failure";
        case audio_engine::start_error_t::connection_not_found:
            return "connection_not_found";
        case audio_engine::start_error_t::offline_output_not_found:
            return "offline_output_not_found";
        case audio_engine::start_error_t::offline_output_starting_failure:
            return "offline_output_starting_failure";
    }
}
