//
//  yas_audio_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_node.h"
#include "yas_audio_connection.h"
#include "yas_audio_time.h"

using namespace yas;

audio_node::audio_node(std::nullptr_t) : super_class(nullptr)
{
}

audio_node::audio_node(const std::shared_ptr<audio_node::impl> &impl) : super_class(impl)
{
    if (impl) {
        impl->set_node(*this);
    }
}

audio_node::~audio_node() = default;

void audio_node::reset()
{
    if (!impl_ptr()) {
        std::cout << "_impl is null" << std::endl;
    }
    _impl_ptr()->reset();
}

audio_format audio_node::input_format(const UInt32 bus_idx) const
{
    return _impl_ptr()->input_format(bus_idx);
}

audio_format audio_node::output_format(const UInt32 bus_idx) const
{
    return _impl_ptr()->output_format(bus_idx);
}

bus_result_t audio_node::next_available_input_bus() const
{
    return _impl_ptr()->next_available_input_bus();
}

bus_result_t audio_node::next_available_output_bus() const
{
    return _impl_ptr()->next_available_output_bus();
}

bool audio_node::is_available_input_bus(const UInt32 bus_idx) const
{
    return _impl_ptr()->is_available_input_bus(bus_idx);
}

bool audio_node::is_available_output_bus(const UInt32 bus_idx) const
{
    return _impl_ptr()->is_available_output_bus(bus_idx);
}

audio_engine audio_node::engine() const
{
    return _impl_ptr()->engine();
}

audio_time audio_node::last_render_time() const
{
    return _impl_ptr()->render_time();
}

UInt32 audio_node::input_bus_count() const
{
    return _impl_ptr()->input_bus_count();
}

UInt32 audio_node::output_bus_count() const
{
    return _impl_ptr()->output_bus_count();
}

#pragma mark render thread

void audio_node::render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when)
{
    _impl_ptr()->render(buffer, bus_idx, when);
}

void audio_node::set_render_time_on_render(const audio_time &time)
{
    _impl_ptr()->set_render_time_on_render(time);
}

#pragma mark - private

std::shared_ptr<audio_node::impl> audio_node::_impl_ptr() const
{
    return impl_ptr<impl>();
}
