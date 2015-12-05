//
//  yas_audio_engine_impl.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_engine.h"
#include "yas_audio_node.h"
#include "yas_audio_unit_node.h"
#include "yas_audio_device_io_node.h"
#include "yas_audio_offline_output_node.h"
#include "yas_audio_graph.h"
#include "yas_stl_utils.h"
#include <CoreFoundation/CoreFoundation.h>
#include <AVFoundation/AVFoundation.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
#include "yas_audio_device.h"
#endif

using namespace yas;

namespace yas
{
    namespace audio
    {
        class connection_for_engine : public connection
        {
            using super_class = connection;

           public:
            connection_for_engine(audio_node &source_node, const UInt32 source_bus, audio_node &destination_node,
                                  const UInt32 destination_bus, const audio::format &format)
                : super_class(source_node, source_bus, destination_node, destination_bus, format)
            {
            }
        };
    }
}

class audio::engine::impl::core
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

    weak<engine> weak_engine;
    objc::container<> reset_observer;
    objc::container<> route_change_observer;
    yas::subject<engine> subject;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    observer<audio::device::change_info> device_observer;
#endif

    yas::audio::graph graph = nullptr;
    std::unordered_set<audio_node> nodes;
    audio::connection_set connections;
    audio_offline_output_node offline_output_node = nullptr;
};

audio::engine::impl::impl() : base::impl(), _core(std::make_unique<core>())
{
}

audio::engine::impl::~impl() = default;

void audio::engine::impl::prepare(const engine &engine)
{
    _core->weak_engine = engine;

#if TARGET_OS_IPHONE
    auto reset_lambda = [weak_engine = _core->weak_engine](NSNotification * note)
    {
        if (auto engine = weak_engine.lock()) {
            engine.impl_ptr<impl>()->reload_graph();
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
            engine.impl_ptr<impl>()->post_configuration_change();
        }
    };

    id route_change_observer =
        [[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionRouteChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:route_change_lambda];
    _core->route_change_observer.set_object(route_change_observer);

#elif TARGET_OS_MAC
    _core->device_observer.add_handler(audio::device::system_subject(), audio::device::configuration_change_key,
                                       [weak_engine = _core->weak_engine](const auto &method, const auto &infos) {
                                           if (auto engine = weak_engine.lock()) {
                                               engine.impl_ptr<impl>()->post_configuration_change();
                                           }
                                       });
#endif
}

weak<audio::engine> &audio::engine::impl::weak_engine() const
{
    return _core->weak_engine;
}

objc::container<> &audio::engine::impl::reset_observer() const
{
    return _core->reset_observer;
}

objc::container<> &audio::engine::impl::route_change_observer() const
{
    return _core->route_change_observer;
}

yas::subject<audio::engine> &audio::engine::impl::subject() const
{
    return _core->subject;
}

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
observer<audio::device::change_info> &audio::engine::impl::device_observer()
{
    return _core->device_observer;
}
#endif

bool audio::engine::impl::node_exists(const audio_node &node)
{
    return _core->nodes.count(node) > 0;
}

void audio::engine::impl::attach_node(audio_node &node)
{
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    if (_core->nodes.count(node) > 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : node is already attached.");
    }

    _core->nodes.insert(node);

    static_cast<audio_node_from_engine &>(node)._set_engine(_core->weak_engine.lock());

    add_node_to_graph(node);
}

void audio::engine::impl::detach_node(audio_node &node)
{
    if (!node) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    if (_core->nodes.count(node) == 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : node is not attached.");
    }

    disconnect_node_with_predicate([&node](const audio::connection &connection) {
        return (connection.destination_node() == node || connection.source_node() == node);
    });

    remove_node_from_graph(node);

    static_cast<audio_node_from_engine &>(node)._set_engine(engine{nullptr});

    _core->nodes.erase(node);
}

void audio::engine::impl::detach_node_if_unused(audio_node &node)
{
    auto filtered_connection = filter(_core->connections, [node](const auto &connection) {
        return (connection.destination_node() == node || connection.source_node() == node);
    });

    if (filtered_connection.size() == 0) {
        detach_node(node);
    }
}

bool audio::engine::impl::prepare()
{
    if (_core->graph) {
        return true;
    }

    _core->graph = yas::audio::graph{};

    for (auto &node : _core->nodes) {
        add_node_to_graph(node);
    }

    for (auto &connection : _core->connections) {
        if (!add_connection(connection)) {
            return false;
        }
    }

    update_all_node_connections();

    return true;
}

audio::connection audio::engine::impl::connect(audio_node &source_node, audio_node &destination_node,
                                               const UInt32 source_bus_idx, const UInt32 destination_bus_idx,
                                               const audio::format &format)
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

    audio::connection_for_engine connection(source_node, source_bus_idx, destination_node, destination_bus_idx, format);

    connections().insert(connection);

    if (graph()) {
        add_connection(connection);
        update_node_connections(source_node);
        update_node_connections(destination_node);
    }

    return connection;
}

void audio::engine::impl::disconnect(audio::connection &connection)
{
    std::vector<audio_node> update_nodes{connection.source_node(), connection.destination_node()};

    remove_connection_from_nodes(connection);
    static_cast<audio::connection_from_engine &>(connection)._remove_nodes();

    for (auto &node : update_nodes) {
        static_cast<audio_node_from_engine &>(node)._update_connections();
        detach_node_if_unused(node);
    }

    connections().erase(connection);
}

void audio::engine::impl::disconnect(audio_node &node)
{
    if (node_exists(node)) {
        detach_node(node);
    }
}

void audio::engine::impl::disconnect_node_with_predicate(std::function<bool(const audio::connection &)> predicate)
{
    auto connections =
        filter(_core->connections, [&predicate](const auto &connection) { return predicate(connection); });

    std::unordered_set<audio_node> update_nodes;

    for (auto connection : connections) {
        update_nodes.insert(connection.source_node());
        update_nodes.insert(connection.destination_node());
        remove_connection_from_nodes(connection);
        static_cast<audio::connection_from_engine &>(connection)._remove_nodes();
    }

    for (auto node : update_nodes) {
        static_cast<audio_node_from_engine &>(node)._update_connections();
        detach_node_if_unused(node);
    }

    for (auto &connection : connections) {
        _core->connections.erase(connection);
    }
}

void audio::engine::impl::add_node_to_graph(const audio_node &node)
{
    if (!_core->graph) {
        return;
    }

    if (auto unit_node = node.cast<audio::unit_node>()) {
        auto &node = static_cast<audio_unit_node_from_engine &>(unit_node);
        node._prepare_audio_unit();
        if (auto unit = unit_node.audio_unit()) {
            _core->graph.add_audio_unit(unit);
        }
        node._prepare_parameters();
    }

#if (!TARGET_OS_IPHONE & TARGET_OS_MAC)
    if (auto device_io_node = node.cast<audio::device_io_node>()) {
        auto &node = static_cast<device_io_node_from_engine &>(device_io_node);
        node._add_device_io();
        _core->graph.add_audio_device_io(node._device_io());
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

void audio::engine::impl::remove_node_from_graph(const audio_node &node)
{
    if (!_core->graph) {
        return;
    }

    if (auto unit_node = node.cast<audio::unit_node>()) {
        if (auto unit = unit_node.audio_unit()) {
            _core->graph.remove_audio_unit(unit);
        }
    }

#if (!TARGET_OS_IPHONE & TARGET_OS_MAC)
    if (auto device_io_node = node.cast<audio::device_io_node>()) {
        auto &node = static_cast<device_io_node_from_engine &>(device_io_node);
        if (auto &device_io = node._device_io()) {
            _core->graph.remove_audio_device_io(device_io);
            node._remove_device_io();
        }
    }
#endif

    if (auto offline_output_node = node.cast<audio_offline_output_node>()) {
        if (offline_output_node == _core->offline_output_node) {
            _core->offline_output_node = nullptr;
        }
    }
}

bool audio::engine::impl::add_connection(const audio::connection &connection)
{
    if (!connection) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        return false;
    }

    auto destination_node = connection.destination_node();
    auto source_node = connection.source_node();

    if (_core->nodes.count(destination_node) == 0 || _core->nodes.count(source_node) == 0) {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : node is not attached.");
        return false;
    }

    static_cast<audio_node_from_engine &>(destination_node)._add_connection(connection);
    static_cast<audio_node_from_engine &>(source_node)._add_connection(connection);

    return true;
}

void audio::engine::impl::remove_connection_from_nodes(const audio::connection &connection)
{
    if (!connection) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
        return;
    }

    if (auto source_node = connection.source_node()) {
        static_cast<audio_node_from_engine &>(source_node)._remove_connection(connection);
    }

    if (auto destination_node = connection.destination_node()) {
        static_cast<audio_node_from_engine &>(destination_node)._remove_connection(connection);
    }
}

void audio::engine::impl::update_node_connections(audio_node &node)
{
    if (!_core->graph) {
        return;
    }

    static_cast<audio_node_from_engine &>(node)._update_connections();
}

void audio::engine::impl::update_all_node_connections()
{
    if (!_core->graph) {
        return;
    }

    for (auto node : _core->nodes) {
        static_cast<audio_node_from_engine &>(node)._update_connections();
    }
}

audio::connection_set audio::engine::impl::input_connections_for_destination_node(const audio_node &node) const
{
    return filter(_core->connections, [node](const auto &connection) { return connection.destination_node() == node; });
}

audio::connection_set audio::engine::impl::output_connections_for_source_node(const audio_node &node) const
{
    return filter(_core->connections, [node](const auto &connection) { return connection.source_node() == node; });
}

void audio::engine::impl::set_graph(const yas::audio::graph &graph)
{
    _core->graph = graph;
}

yas::audio::graph audio::engine::impl::graph() const
{
    return _core->graph;
}

void audio::engine::impl::reload_graph()
{
    if (auto prev_graph = graph()) {
        const bool prev_runnging = prev_graph.is_running();

        prev_graph.stop();

        for (auto &node : nodes()) {
            remove_node_from_graph(node);
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

std::unordered_set<audio_node> &audio::engine::impl::nodes() const
{
    return _core->nodes;
}

audio::connection_set &audio::engine::impl::connections() const
{
    return _core->connections;
}

audio_offline_output_node &audio::engine::impl::offline_output_node() const
{
    return _core->offline_output_node;
}

audio::engine::start_result_t audio::engine::impl::start_render()
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

audio::engine::start_result_t audio::engine::impl::start_offline_render(const offline_render_f &render_function,
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

    auto &node_from_engine = static_cast<audio_offline_output_unit_from_engine &>(offline_output_node);
    auto result = node_from_engine._start(render_function, completion_function);

    if (result) {
        return start_result_t(nullptr);
    } else {
        return start_result_t(start_error_t::offline_output_starting_failure);
    }
}

void audio::engine::impl::stop()
{
    if (auto graph = _core->graph) {
        graph.stop();
    }

    if (auto offline_output_node = _core->offline_output_node) {
        static_cast<audio_offline_output_unit_from_engine &>(offline_output_node)._stop();
    }
}

void audio::engine::impl::post_configuration_change() const
{
    subject().notify(configuration_change_key, _core->weak_engine.lock());
}
