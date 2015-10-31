//
//  yas_audio_tap_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_tap_node.h"

using namespace yas;

audio_tap_node::audio_tap_node() : super_class(std::make_unique<impl>(), create_tag)
{
}

audio_tap_node::audio_tap_node(std::nullptr_t) : super_class(nullptr)
{
}

audio_tap_node::audio_tap_node(const std::shared_ptr<impl> &impl) : super_class(impl)
{
}

audio_tap_node::~audio_tap_node() = default;

void audio_tap_node::set_render_function(const render_f &func)
{
    _impl_ptr()->set_render_function(func);
}

audio_connection audio_tap_node::input_connection_on_render(const UInt32 bus_idx) const
{
    return _impl_ptr()->input_connection_on_render(bus_idx);
}

audio_connection audio_tap_node::output_connection_on_render(const UInt32 bus_idx) const
{
    return _impl_ptr()->output_connection_on_render(bus_idx);
}

audio_connection_smap audio_tap_node::input_connections_on_render() const
{
    return _impl_ptr()->input_connections_on_render();
}

audio_connection_smap audio_tap_node::output_connections_on_render() const
{
    return _impl_ptr()->output_connections_on_render();
}

void audio_tap_node::render_source(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when)
{
    _impl_ptr()->render_source(buffer, bus_idx, when);
}

#pragma mark - private

std::shared_ptr<audio_tap_node::impl> audio_tap_node::_impl_ptr() const
{
    return std::dynamic_pointer_cast<audio_tap_node::impl>(_impl);
}

#pragma mark - input_tap_node

audio_input_tap_node::audio_input_tap_node() : super_class(std::make_unique<impl>())
{
}

audio_input_tap_node::audio_input_tap_node(std::nullptr_t) : super_class(nullptr)
{
}

audio_input_tap_node::audio_input_tap_node(const audio_node &node, audio_node::cast_tag_t)
    : super_class(std::dynamic_pointer_cast<audio_input_tap_node::impl>(audio_node::private_access::impl(node)))
{
}
