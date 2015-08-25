//
//  yas_audio_tap_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_tap_node.h"

using namespace yas;

#pragma mark - node_core

namespace yas
{
    class audio_tap_node_core : public audio_node_core
    {
       public:
        audio_tap_node::render_function render_function;
    };
}

#pragma mark - tap_node

class audio_tap_node::impl
{
   public:
    render_function render_function;

    void set_node_core_on_render(const audio_node_core_ptr &node_core)
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        _node_core_on_render = node_core;
    }

    audio_node_core_ptr node_core_on_render() const
    {
        std::lock_guard<std::recursive_mutex> lock(_mutex);
        return _node_core_on_render;
    }

   private:
    audio_node_core_ptr _node_core_on_render;
    mutable std::recursive_mutex _mutex;
};

audio_tap_node_sptr audio_tap_node::create()
{
    return audio_tap_node_sptr(new audio_tap_node());
}

audio_tap_node::audio_tap_node() : audio_node(), _impl(std::make_unique<impl>())
{
}

audio_tap_node::~audio_tap_node() = default;

void audio_tap_node::set_render_function(const render_function &render_function)
{
    _impl->render_function = render_function;

    update_node_core();
}

uint32_t audio_tap_node::input_bus_count() const
{
    return 1;
}

uint32_t audio_tap_node::output_bus_count() const
{
    return 1;
}

void audio_tap_node::render(const audio_pcm_buffer_sptr &buffer, const uint32_t bus_idx, const audio_time_sptr &when)
{
    super_class::render(buffer, bus_idx, when);

    if (auto core = node_core()) {
        _impl->set_node_core_on_render(core);

        audio_tap_node_core *tap_node_core = dynamic_cast<audio_tap_node_core *>(core.get());
        auto &render_function = tap_node_core->render_function;

        if (render_function) {
            render_function(buffer, bus_idx, when);
        } else {
            render_source(buffer, bus_idx, when);
        }

        _impl->set_node_core_on_render(nullptr);
    }
}

audio_connection_sptr audio_tap_node::input_connection_on_render(const uint32_t bus_idx) const
{
    return _impl->node_core_on_render()->input_connection(bus_idx);
}

audio_connection_sptr audio_tap_node::output_connection_on_render(const uint32_t bus_idx) const
{
    return _impl->node_core_on_render()->output_connection(bus_idx);
}

audio_connection_wmap &audio_tap_node::input_connections_on_render() const
{
    return _impl->node_core_on_render()->input_connections;
}

audio_connection_wmap &audio_tap_node::output_connections_on_render() const
{
    return _impl->node_core_on_render()->output_connections;
}

void audio_tap_node::render_source(const audio_pcm_buffer_sptr &buffer, const uint32_t bus_idx, const audio_time_sptr &when)
{
    if (auto connection = input_connection_on_render(bus_idx)) {
        if (auto node = connection->source_node()) {
            node->render(buffer, connection->source_bus(), when);
        }
    }
}

audio_node_core_ptr audio_tap_node::make_node_core()
{
    return audio_node_core_ptr(new audio_tap_node_core());
}

void audio_tap_node::prepare_node_core(const audio_node_core_ptr &node_core)
{
    super_class::prepare_node_core(node_core);

    if (audio_tap_node_core *tap_node_core = dynamic_cast<audio_tap_node_core *>(node_core.get())) {
        tap_node_core->render_function = _impl->render_function;
    } else {
        throw std::runtime_error(std::string(__PRETTY_FUNCTION__) + " : failed dynamic cast to audio_tap_node_core.");
    }
}

#pragma mark - input_tap_node

audio_input_tap_node_sptr audio_input_tap_node::create()
{
    return audio_input_tap_node_sptr(new audio_input_tap_node());
}

uint32_t audio_input_tap_node::input_bus_count() const
{
    return 1;
}

uint32_t audio_input_tap_node::output_bus_count() const
{
    return 0;
}
