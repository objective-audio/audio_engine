//
//  yas_audio_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_node.h"
#include "yas_audio_engine.h"
#include "yas_audio_connection.h"
#include "yas_audio_time.h"

using namespace yas;

audio_node::audio_node(std::nullptr_t) : super_class(nullptr)
{
}

audio_node::audio_node(const std::shared_ptr<audio_node::impl> &impl) : super_class(impl)
{
}

audio_node::~audio_node() = default;

void audio_node::reset()
{
    if (!impl_ptr()) {
        std::cout << "_impl is null" << std::endl;
    }
    impl_ptr<impl>()->reset();
}

audio::format audio_node::input_format(const UInt32 bus_idx) const
{
    return impl_ptr<impl>()->input_format(bus_idx);
}

audio::format audio_node::output_format(const UInt32 bus_idx) const
{
    return impl_ptr<impl>()->output_format(bus_idx);
}

bus_result_t audio_node::next_available_input_bus() const
{
    return impl_ptr<impl>()->next_available_input_bus();
}

bus_result_t audio_node::next_available_output_bus() const
{
    return impl_ptr<impl>()->next_available_output_bus();
}

bool audio_node::is_available_input_bus(const UInt32 bus_idx) const
{
    return impl_ptr<impl>()->is_available_input_bus(bus_idx);
}

bool audio_node::is_available_output_bus(const UInt32 bus_idx) const
{
    return impl_ptr<impl>()->is_available_output_bus(bus_idx);
}

audio_engine audio_node::engine() const
{
    return impl_ptr<impl>()->engine();
}

audio::time audio_node::last_render_time() const
{
    return impl_ptr<impl>()->render_time();
}

UInt32 audio_node::input_bus_count() const
{
    return impl_ptr<impl>()->input_bus_count();
}

UInt32 audio_node::output_bus_count() const
{
    return impl_ptr<impl>()->output_bus_count();
}

#pragma mark render thread

void audio_node::render(audio::pcm_buffer &buffer, const UInt32 bus_idx, const audio::time &when)
{
    impl_ptr<impl>()->render(buffer, bus_idx, when);
}

void audio_node::set_render_time_on_render(const audio::time &time)
{
    impl_ptr<impl>()->set_render_time_on_render(time);
}

#pragma mark - private

audio_connection audio_node::_input_connection(const UInt32 bus_idx) const
{
    return impl_ptr<impl>()->input_connection(bus_idx);
}

audio_connection audio_node::_output_connection(const UInt32 bus_idx) const
{
    return impl_ptr<impl>()->output_connection(bus_idx);
}

const audio_connection_wmap &audio_node::_input_connections() const
{
    return impl_ptr<impl>()->input_connections();
}

const audio_connection_wmap &audio_node::_output_connections() const
{
    return impl_ptr<impl>()->output_connections();
}

void audio_node::_add_connection(const audio_connection &connection)
{
    impl_ptr<impl>()->add_connection(connection);
}

void audio_node::_remove_connection(const audio_connection &connection)
{
    impl_ptr<impl>()->remove_connection(connection);
}

void audio_node::_set_engine(const audio_engine &engine)
{
    impl_ptr<impl>()->set_engine(engine);
}

audio_engine audio_node::_engine() const
{
    return impl_ptr<impl>()->engine();
}

void audio_node::_update_kernel()
{
    impl_ptr<impl>()->update_kernel();
}

void audio_node::_update_connections()
{
    impl_ptr<impl>()->update_connections();
}
