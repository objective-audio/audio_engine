//
//  yas_audio_tap_node.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_tap_node.h"

using namespace yas;

#pragma mark - kernel

class audio_tap_node::kernel : public audio_node::kernel
{
   public:
    ~kernel() = default;

    audio_tap_node::render_f render_function;
};

#pragma mark - impl

class audio_tap_node::impl : public super_class::impl
{
   public:
    class core
    {
       public:
        render_f render_function;
        std::shared_ptr<kernel> kernel_on_render;
    };

    impl() : audio_node::impl(), _core(std::make_unique<core>())
    {
    }

    ~impl() = default;

    virtual UInt32 input_bus_count() const override
    {
        return 1;
    }

    virtual UInt32 output_bus_count() const override
    {
        return 1;
    }

    virtual std::shared_ptr<audio_node::kernel> make_kernel() override
    {
        return std::shared_ptr<kernel>(new audio_tap_node::kernel());
    }

    virtual void prepare_kernel(const std::shared_ptr<audio_node::kernel> &kernel) override
    {
        super_class::prepare_kernel(kernel);

        if (auto tap_kernel = std::dynamic_pointer_cast<audio_tap_node::kernel>(kernel)) {
            tap_kernel->render_function = _core->render_function;
        } else {
            throw std::runtime_error(std::string(__PRETTY_FUNCTION__) +
                                     " : failed dynamic cast to audio_tap_node::kernel.");
        }
    }

    std::unique_ptr<core> _core;

   private:
    using super_class = super_class::impl;
};

#pragma mark - main

audio_tap_node_sptr audio_tap_node::create()
{
    return audio_tap_node_sptr(new audio_tap_node(std::make_unique<impl>()));
}

audio_tap_node::audio_tap_node() : super_class(std::make_unique<impl>())
{
}

audio_tap_node::audio_tap_node(std::unique_ptr<impl> &&impl) : super_class(std::move(impl))
{
}

audio_tap_node::~audio_tap_node() = default;

void audio_tap_node::set_render_function(const render_f &render_function)
{
    _impl_ptr()->_core->render_function = render_function;

    update_kernel();
}

void audio_tap_node::render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when)
{
    super_class::render(buffer, bus_idx, when);

    if (auto kernel = _kernel()) {
        _impl_ptr()->_core->kernel_on_render = kernel;

        auto &render_function = kernel->render_function;

        if (render_function) {
            render_function(buffer, bus_idx, when);
        } else {
            render_source(buffer, bus_idx, when);
        }

        _impl_ptr()->_core->kernel_on_render = nullptr;
    }
}

audio_connection audio_tap_node::input_connection_on_render(const UInt32 bus_idx) const
{
    return _impl_ptr()->_core->kernel_on_render->input_connection(bus_idx);
}

audio_connection audio_tap_node::output_connection_on_render(const UInt32 bus_idx) const
{
    return _impl_ptr()->_core->kernel_on_render->output_connection(bus_idx);
}

audio_connection_smap audio_tap_node::input_connections_on_render() const
{
    return _impl_ptr()->_core->kernel_on_render->input_connections();
}

audio_connection_smap audio_tap_node::output_connections_on_render() const
{
    return _impl_ptr()->_core->kernel_on_render->output_connections();
}

void audio_tap_node::render_source(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when)
{
    if (auto connection = input_connection_on_render(bus_idx)) {
        if (auto node = connection.source_node()) {
            node->render(buffer, connection.source_bus(), when);
        }
    }
}

#pragma mark - private

std::shared_ptr<audio_tap_node::kernel> audio_tap_node::_kernel() const
{
    return std::static_pointer_cast<audio_tap_node::kernel>(super_class::_kernel());
}

audio_tap_node::impl *audio_tap_node::_impl_ptr() const
{
    return dynamic_cast<audio_tap_node::impl *>(_impl.get());
}

#pragma mark - input_tap_node

class audio_input_tap_node::impl : public super_class::impl
{
    virtual UInt32 input_bus_count() const override
    {
        return 1;
    }

    virtual UInt32 output_bus_count() const override
    {
        return 0;
    }
};

audio_input_tap_node_sptr audio_input_tap_node::create()
{
    return audio_input_tap_node_sptr(new audio_input_tap_node());
}

audio_input_tap_node::audio_input_tap_node() : audio_tap_node(std::make_unique<impl>())
{
}
