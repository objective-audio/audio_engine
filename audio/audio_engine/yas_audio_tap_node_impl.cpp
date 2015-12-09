//
//  yas_audio_tap_node_impl.cpp
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "yas_audio_tap_node.h"

using namespace yas;

class audio::tap_node::kernel : public node::kernel {
   public:
    ~kernel() = default;

    audio::tap_node::render_f render_function;
};

class audio::tap_node::impl::core {
   public:
    render_f render_function;
    std::shared_ptr<kernel> kernel_on_render;
};

audio::tap_node::impl::impl() : node::impl(), _core(std::make_unique<core>()) {
}

audio::tap_node::impl::~impl() = default;

void audio::tap_node::impl::reset() {
    _core->render_function = nullptr;
    super_class::reset();
}

UInt32 audio::tap_node::impl::input_bus_count() const {
    return 1;
}

UInt32 audio::tap_node::impl::output_bus_count() const {
    return 1;
}

std::shared_ptr<audio::node::kernel> audio::tap_node::impl::make_kernel() {
    return std::shared_ptr<kernel>(new kernel());
}

void audio::tap_node::impl::prepare_kernel(const std::shared_ptr<node::kernel> &kernel) {
    super_class::prepare_kernel(kernel);

    auto tap_kernel = std::static_pointer_cast<tap_node::kernel>(kernel);
    tap_kernel->render_function = _core->render_function;
}

void audio::tap_node::impl::set_render_function(const render_f &func) {
    _core->render_function = func;

    update_kernel();
}

audio::connection audio::tap_node::impl::input_connection_on_render(const UInt32 bus_idx) const {
    return _core->kernel_on_render->input_connection(bus_idx);
}

audio::connection audio::tap_node::impl::output_connection_on_render(const UInt32 bus_idx) const {
    return _core->kernel_on_render->output_connection(bus_idx);
}

audio::connection_smap audio::tap_node::impl::input_connections_on_render() const {
    return _core->kernel_on_render->input_connections();
}

audio::connection_smap audio::tap_node::impl::output_connections_on_render() const {
    return _core->kernel_on_render->output_connections();
}

void audio::tap_node::impl::render(pcm_buffer &buffer, const UInt32 bus_idx, const time &when) {
    super_class::render(buffer, bus_idx, when);

    if (auto kernel = kernel_cast<tap_node::kernel>()) {
        _core->kernel_on_render = kernel;

        auto &render_function = kernel->render_function;

        if (render_function) {
            render_function(buffer, bus_idx, when);
        } else {
            render_source(buffer, bus_idx, when);
        }

        _core->kernel_on_render = nullptr;
    }
}

void audio::tap_node::impl::render_source(pcm_buffer &buffer, const UInt32 bus_idx, const time &when) {
    if (auto connection = _core->kernel_on_render->input_connection(bus_idx)) {
        if (auto node = connection.source_node()) {
            node.render(buffer, connection.source_bus(), when);
        }
    }
}

#pragma mark - input_tap_node

UInt32 audio::input_tap_node::impl::input_bus_count() const {
    return 1;
}

UInt32 audio::input_tap_node::impl::output_bus_count() const {
    return 0;
}
