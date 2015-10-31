//
//  yas_audio_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_node.h"
#include "yas_audio_connection.h"
#include "yas_audio_time.h"

using namespace yas;

audio_node::audio_node(std::nullptr_t) : _impl(nullptr)
{
}

audio_node::audio_node(std::shared_ptr<impl> &&impl, create_tag_t) : _impl(std::move(impl))
{
    if (_impl) {
        _impl->set_node(*this);
    }
}

audio_node::audio_node(const std::shared_ptr<audio_node::impl> &impl) : _impl(impl)
{
    if (_impl) {
        _impl->set_node(*this);
    }
}

audio_node::~audio_node() = default;

audio_node &audio_node::operator=(std::nullptr_t)
{
    _impl = nullptr;
    return *this;
}

bool audio_node::operator==(const audio_node &other)
{
    return _impl && other._impl && _impl == other._impl;
}

bool audio_node::operator!=(const audio_node &other)
{
    return !_impl || !other._impl || _impl != other._impl;
}

bool audio_node::expired() const
{
    return !_impl;
}

audio_node::operator bool() const
{
    return !expired();
}

uintptr_t audio_node::key() const
{
    return reinterpret_cast<uintptr_t>(&*_impl);
}

void audio_node::reset()
{
    if (!_impl) {
        std::cout << "_impl is null" << std::endl;
    }
    _impl->reset();
}

audio_format audio_node::input_format(const UInt32 bus_idx) const
{
    return _impl->input_format(bus_idx);
}

audio_format audio_node::output_format(const UInt32 bus_idx) const
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
    return _impl->engine();
}

audio_time audio_node::last_render_time() const
{
    return _impl->render_time();
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
    _impl->render(buffer, bus_idx, when);
}

void audio_node::set_render_time_on_render(const audio_time &time)
{
    _impl->set_render_time_on_render(time);
}

#pragma mark - protected

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
