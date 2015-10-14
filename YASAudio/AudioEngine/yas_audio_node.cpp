//
//  yas_audio_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_node.h"
#include "yas_audio_connection.h"
#include "yas_audio_time.h"
#include "yas_stl_utils.h"
#include <mutex>
#include <exception>

using namespace yas;

class audio_node_core::impl
{
   public:
    audio_connection_wmap input_connections;
    audio_connection_wmap output_connections;
};

audio_node_core::audio_node_core() : _impl(std::make_unique<impl>())
{
}

audio_node_core::~audio_node_core() = default;

audio_connection_smap audio_node_core::input_connections() const
{
    return yas::lock_values(_impl->input_connections);
}

audio_connection_smap audio_node_core::output_connections() const
{
    return yas::lock_values(_impl->output_connections);
}

audio_connection audio_node_core::input_connection(const UInt32 bus_idx)
{
    if (_impl->input_connections.count(bus_idx) > 0) {
        return _impl->input_connections.at(bus_idx).lock();
    }
    return nullptr;
}

audio_connection audio_node_core::output_connection(const UInt32 bus_idx)
{
    if (_impl->output_connections.count(bus_idx) > 0) {
        return _impl->output_connections.at(bus_idx).lock();
    }
    return nullptr;
}

void audio_node_core::_set_input_connections(const audio_connection_wmap &connections)
{
    _impl->input_connections = connections;
}

void audio_node_core::_set_output_connections(const audio_connection_wmap &connections)
{
    _impl->output_connections = connections;
}

#pragma mark - impl

class audio_node::impl
{
   public:
    audio_engine::weak weak_engine;

    impl() : weak_engine(), _input_connections(), _output_connections(), _node_core(nullptr), _render_time(), _mutex()
    {
    }

    audio_connection_wmap &input_connections()
    {
        return _input_connections;
    }

    audio_connection_wmap &output_connections()
    {
        return _output_connections;
    }

    void set_node_core(const audio_node_core_sptr &node_core)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _node_core = node_core;
    }

    audio_node_core_sptr node_core() const
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _node_core;
    }

    void set_render_time(const audio_time &render_time)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _render_time = render_time;
    }

    audio_time render_time() const
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _render_time;
    }

   private:
    audio_connection_wmap _input_connections;
    audio_connection_wmap _output_connections;
    audio_node_core_sptr _node_core;
    audio_time _render_time;
    mutable std::recursive_mutex _mutex;
};

#pragma mark - main

audio_node::audio_node() : _impl(std::make_unique<impl>())
{
}

audio_node::~audio_node() = default;

bool audio_node::operator==(const audio_node &node)
{
    return this == &node;
}

void audio_node::reset()
{
    _impl->input_connections().clear();
    _impl->output_connections().clear();

    update_node_core();
}

audio_format audio_node::input_format(const UInt32 bus_idx)
{
    if (auto connection = input_connection(bus_idx)) {
        return connection.format();
    }
    return nullptr;
}

audio_format audio_node::output_format(const UInt32 bus_idx)
{
    if (auto connection = output_connection(bus_idx)) {
        return connection.format();
    }
    return nullptr;
}

bus_result_t audio_node::next_available_input_bus() const
{
    auto key = min_empty_key(_impl->input_connections());
    if (key && *key < input_bus_count()) {
        return key;
    }
    return nullopt;
}

bus_result_t audio_node::next_available_output_bus() const
{
    auto key = min_empty_key(_impl->output_connections());
    if (key && *key < output_bus_count()) {
        return key;
    }
    return nullopt;
}

bool audio_node::is_available_input_bus(const UInt32 bus_idx) const
{
    if (bus_idx >= input_bus_count()) {
        return false;
    }
    return _impl->input_connections().count(bus_idx) == 0;
}

bool audio_node::is_available_output_bus(const UInt32 bus_idx) const
{
    if (bus_idx >= output_bus_count()) {
        return false;
    }
    return _impl->output_connections().count(bus_idx) == 0;
}

audio_engine audio_node::engine() const
{
    return _impl->weak_engine.lock();
}

audio_time audio_node::last_render_time() const
{
    return _impl->render_time();
}

UInt32 audio_node::input_bus_count() const
{
    return 0;
}

UInt32 audio_node::output_bus_count() const
{
    return 0;
}

#pragma mark render thread

void audio_node::render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when)
{
    set_render_time_on_render(when);
}

#pragma mark - protected

void audio_node::update_connections()
{
}

audio_node_core_sptr audio_node::make_node_core()
{
    return audio_node_core_sptr(new audio_node_core());
}

void audio_node::prepare_node_core(const audio_node_core_sptr &node_core)
{
    if (!node_core) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    audio_node_core::private_access::set_input_connections(node_core, _impl->input_connections());
    audio_node_core::private_access::set_output_connections(node_core, _impl->output_connections());
}

void audio_node::update_node_core()
{
    auto node_core = make_node_core();
    prepare_node_core(node_core);
    _impl->set_node_core(node_core);
}

#pragma mark - private

void audio_node::_set_engine(const audio_engine &engine)
{
    _impl->weak_engine = engine;
}

void audio_node::_add_connection(const audio_connection &connection)
{
    if (*connection.destination_node() == *this) {
        auto bus_idx = connection.destination_bus();
        _impl->input_connections().insert(std::make_pair(bus_idx, audio_connection::weak(connection)));
    } else if (*connection.source_node() == *this) {
        auto bus_idx = connection.source_bus();
        _impl->output_connections().insert(std::make_pair(bus_idx, audio_connection::weak(connection)));
    } else {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : connection does not exist in a node.");
    }

    update_node_core();
}

void audio_node::_remove_connection(const audio_connection &connection)
{
    if (*connection.destination_node() == *this) {
        _impl->input_connections().erase(connection.destination_bus());
    }

    if (*connection.source_node() == *this) {
        _impl->output_connections().erase(connection.source_bus());
    }

    update_node_core();
}

audio_connection audio_node::input_connection(const UInt32 bus_idx) const
{
    if (_impl->input_connections().count(bus_idx) > 0) {
        return _impl->input_connections().at(bus_idx).lock();
    }
    return nullptr;
}

audio_connection audio_node::output_connection(const UInt32 bus_idx) const
{
    if (_impl->output_connections().count(bus_idx) > 0) {
        return _impl->output_connections().at(bus_idx).lock();
    }
    return nullptr;
}

const audio_connection_wmap &audio_node::input_connections() const
{
    return _impl->input_connections();
}

const audio_connection_wmap &audio_node::output_connections() const
{
    return _impl->output_connections();
}

#pragma mark render thread

audio_node_core_sptr audio_node::node_core() const
{
    return _impl->node_core();
}

void audio_node::set_render_time_on_render(const audio_time &time)
{
    _impl->set_render_time(time);
}
