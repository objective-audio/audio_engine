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

class audio_node::kernel::impl
{
   public:
    audio_connection_wmap input_connections;
    audio_connection_wmap output_connections;
};

audio_node::kernel::kernel() : _impl(std::make_unique<impl>())
{
}

audio_node::kernel::~kernel() = default;

audio_connection_smap audio_node::kernel::input_connections() const
{
    return yas::lock_values(_impl->input_connections);
}

audio_connection_smap audio_node::kernel::output_connections() const
{
    return yas::lock_values(_impl->output_connections);
}

audio_connection audio_node::kernel::input_connection(const UInt32 bus_idx)
{
    if (_impl->input_connections.count(bus_idx) > 0) {
        return _impl->input_connections.at(bus_idx).lock();
    }
    return nullptr;
}

audio_connection audio_node::kernel::output_connection(const UInt32 bus_idx)
{
    if (_impl->output_connections.count(bus_idx) > 0) {
        return _impl->output_connections.at(bus_idx).lock();
    }
    return nullptr;
}

void audio_node::kernel::_set_input_connections(const audio_connection_wmap &connections)
{
    _impl->input_connections = connections;
}

void audio_node::kernel::_set_output_connections(const audio_connection_wmap &connections)
{
    _impl->output_connections = connections;
}

#pragma mark - impl

class audio_node::impl::core
{
   public:
    audio_engine::weak weak_engine;

    core() : weak_engine(), _input_connections(), _output_connections(), _kernel(nullptr), _render_time(), _mutex()
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

    void set_kernel(const std::shared_ptr<kernel> &kernel)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _kernel = kernel;
    }

    std::shared_ptr<kernel> kernel() const
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _kernel;
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
    std::shared_ptr<audio_node::kernel> _kernel;
    audio_time _render_time;
    mutable std::recursive_mutex _mutex;
};

audio_node::impl::impl() : _core(std::make_unique<core>())
{
}

audio_node::impl::~impl() = default;

audio_format audio_node::impl::input_format(const UInt32 bus_idx)
{
    if (auto connection = input_connection(bus_idx)) {
        return connection.format();
    }
    return nullptr;
}

audio_format audio_node::impl::output_format(const UInt32 bus_idx)
{
    if (auto connection = output_connection(bus_idx)) {
        return connection.format();
    }
    return nullptr;
}

bus_result_t audio_node::impl::next_available_input_bus() const
{
    auto key = min_empty_key(_core->input_connections());
    if (key && *key < input_bus_count()) {
        return key;
    }
    return nullopt;
}

bus_result_t audio_node::impl::next_available_output_bus() const
{
    auto key = min_empty_key(_core->output_connections());
    if (key && *key < output_bus_count()) {
        return key;
    }
    return nullopt;
}

bool audio_node::impl::is_available_input_bus(const UInt32 bus_idx) const
{
    if (bus_idx >= input_bus_count()) {
        return false;
    }
    return _core->input_connections().count(bus_idx) == 0;
}

bool audio_node::impl::is_available_output_bus(const UInt32 bus_idx) const
{
    if (bus_idx >= output_bus_count()) {
        return false;
    }
    return _core->output_connections().count(bus_idx) == 0;
}

UInt32 audio_node::impl::input_bus_count() const
{
    return 0;
}

UInt32 audio_node::impl::output_bus_count() const
{
    return 0;
}

audio_connection audio_node::impl::input_connection(const UInt32 bus_idx) const
{
    if (_core->input_connections().count(bus_idx) > 0) {
        return _core->input_connections().at(bus_idx).lock();
    }
    return nullptr;
}

audio_connection audio_node::impl::output_connection(const UInt32 bus_idx) const
{
    if (_core->output_connections().count(bus_idx) > 0) {
        return _core->output_connections().at(bus_idx).lock();
    }
    return nullptr;
}

const audio_connection_wmap &audio_node::impl::input_connections() const
{
    return _core->input_connections();
}

const audio_connection_wmap &audio_node::impl::output_connections() const
{
    return _core->output_connections();
}

void audio_node::impl::update_connections()
{
}

std::shared_ptr<audio_node::kernel> audio_node::impl::make_kernel()
{
    return std::shared_ptr<kernel>(new kernel());
}

void audio_node::impl::prepare_kernel(const std::shared_ptr<kernel> &kernel)
{
    if (!kernel) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : argument is null.");
    }

    kernel::private_access::set_input_connections(kernel, _core->input_connections());
    kernel::private_access::set_output_connections(kernel, _core->output_connections());
}

void audio_node::impl::update_kernel()
{
    auto kernel = make_kernel();
    prepare_kernel(kernel);
    _core->set_kernel(kernel);
}

#pragma mark - main

audio_node::audio_node(std::shared_ptr<impl> &&impl) : _impl(std::move(impl))
{
}

audio_node::audio_node(const std::shared_ptr<audio_node::impl> &impl) : _impl(impl)
{
}

audio_node::~audio_node() = default;

bool audio_node::operator==(const audio_node &other)
{
    return _impl && other._impl && _impl == other._impl;
}

bool audio_node::operator!=(const audio_node &other)
{
    return !_impl || !other._impl || _impl != other._impl;
}

audio_node::operator bool() const
{
    return _impl != nullptr;
}

void audio_node::reset()
{
    _impl->_core->input_connections().clear();
    _impl->_core->output_connections().clear();

    update_kernel();
}

audio_format audio_node::input_format(const UInt32 bus_idx)
{
    return _impl->input_format(bus_idx);
}

audio_format audio_node::output_format(const UInt32 bus_idx)
{
    return _impl->output_format(bus_idx);
}

bus_result_t audio_node::next_available_input_bus() const
{
    return _impl->next_available_input_bus();
}

bus_result_t audio_node::next_available_output_bus() const
{
    return _impl->next_available_output_bus();
}

bool audio_node::is_available_input_bus(const UInt32 bus_idx) const
{
    return _impl->is_available_input_bus(bus_idx);
}

bool audio_node::is_available_output_bus(const UInt32 bus_idx) const
{
    return _impl->is_available_output_bus(bus_idx);
}

audio_engine audio_node::engine() const
{
    return _impl->_core->weak_engine.lock();
}

audio_time audio_node::last_render_time() const
{
    return _impl->_core->render_time();
}

UInt32 audio_node::input_bus_count() const
{
    return _impl->input_bus_count();
}

UInt32 audio_node::output_bus_count() const
{
    return _impl->output_bus_count();
}

#pragma mark render thread

void audio_node::render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when)
{
    set_render_time_on_render(when);
}

#pragma mark - protected

void audio_node::update_connections()
{
    _impl->update_connections();
}

std::shared_ptr<audio_node::kernel> audio_node::make_kernel()
{
    return _impl->make_kernel();
}

void audio_node::prepare_kernel(const std::shared_ptr<kernel> &kernel)
{
    _impl->prepare_kernel(kernel);
}

void audio_node::update_kernel()
{
    _impl->update_kernel();
}

#pragma mark - private

void audio_node::_set_engine(const audio_engine &engine)
{
    _impl->_core->weak_engine = engine;
}

void audio_node::_add_connection(const audio_connection &connection)
{
    if (*connection.destination_node() == *this) {
        auto bus_idx = connection.destination_bus();
        _impl->_core->input_connections().insert(std::make_pair(bus_idx, audio_connection::weak(connection)));
    } else if (*connection.source_node() == *this) {
        auto bus_idx = connection.source_bus();
        _impl->_core->output_connections().insert(std::make_pair(bus_idx, audio_connection::weak(connection)));
    } else {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : connection does not exist in a node.");
    }

    update_kernel();
}

void audio_node::_remove_connection(const audio_connection &connection)
{
    if (auto destination_node = connection.destination_node()) {
        if (*connection.destination_node() == *this) {
            _impl->_core->input_connections().erase(connection.destination_bus());
        }
    }

    if (auto source_node = connection.source_node()) {
        if (*connection.source_node() == *this) {
            _impl->_core->output_connections().erase(connection.source_bus());
        }
    }

    update_kernel();
}

audio_connection audio_node::input_connection(const UInt32 bus_idx) const
{
    return _impl->input_connection(bus_idx);
}

audio_connection audio_node::output_connection(const UInt32 bus_idx) const
{
    return _impl->output_connection(bus_idx);
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

std::shared_ptr<audio_node::kernel> audio_node::_kernel() const
{
    return _impl->_core->kernel();
}

void audio_node::set_render_time_on_render(const audio_time &time)
{
    _impl->_core->set_render_time(time);
}
