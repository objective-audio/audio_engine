//
//  yas_audio_tap_node_impl.cpp
//

#include "yas_audio_tap_node.h"

using namespace yas;

struct audio::tap_node::kernel : node::kernel {
    struct impl : node::kernel::impl {
        audio::tap_node::render_f render_function;
    };

    kernel() : node::kernel(std::make_shared<impl>()) {
    }

    kernel(std::nullptr_t) : node::kernel(nullptr) {
    }

    void set_render_function(audio::tap_node::render_f func) {
        impl_ptr<impl>()->render_function = std::move(func);
    }

    audio::tap_node::render_f const &render_function() {
        return impl_ptr<impl>()->render_function;
    }
};

struct audio::tap_node::impl::core {
    render_f render_function;
    tap_node::kernel kernel_on_render;
};

audio::tap_node::impl::impl() : node::impl(), _core(std::make_unique<core>()) {
}

audio::tap_node::impl::~impl() = default;

void audio::tap_node::impl::reset() {
    _core->render_function = nullptr;
    node::impl::reset();
}

uint32_t audio::tap_node::impl::input_bus_count() const {
    return 1;
}

uint32_t audio::tap_node::impl::output_bus_count() const {
    return 1;
}

audio::node::kernel audio::tap_node::impl::make_kernel() {
    return audio::tap_node::kernel{};
}

void audio::tap_node::impl::prepare_kernel(audio::node::kernel &kernel) {
    node::impl::prepare_kernel(kernel);

    auto tap_kernel = yas::cast<audio::tap_node::kernel>(kernel);
    tap_kernel.set_render_function(_core->render_function);
}

void audio::tap_node::impl::set_render_function(render_f &&func) {
    _core->render_function = func;

    update_kernel();
}

audio::connection audio::tap_node::impl::input_connection_on_render(uint32_t const bus_idx) const {
    return _core->kernel_on_render.input_connection(bus_idx);
}

audio::connection audio::tap_node::impl::output_connection_on_render(uint32_t const bus_idx) const {
    return _core->kernel_on_render.output_connection(bus_idx);
}

audio::connection_smap audio::tap_node::impl::input_connections_on_render() const {
    return _core->kernel_on_render.input_connections();
}

audio::connection_smap audio::tap_node::impl::output_connections_on_render() const {
    return _core->kernel_on_render.output_connections();
}

void audio::tap_node::impl::render(pcm_buffer &buffer, uint32_t const bus_idx, time const &when) {
    node::impl::render(buffer, bus_idx, when);

    if (auto kernel = kernel_cast<tap_node::kernel>()) {
        _core->kernel_on_render = kernel;

        auto const &render_function = kernel.render_function();

        if (render_function) {
            render_function(buffer, bus_idx, when);
        } else {
            render_source(buffer, bus_idx, when);
        }

        _core->kernel_on_render = nullptr;
    }
}

void audio::tap_node::impl::render_source(pcm_buffer &buffer, uint32_t const bus_idx, time const &when) {
    if (auto connection = _core->kernel_on_render.input_connection(bus_idx)) {
        if (auto node = connection.source_node()) {
            node.render(buffer, connection.source_bus(), when);
        }
    }
}

#pragma mark - input_tap_node

uint32_t audio::input_tap_node::impl::input_bus_count() const {
    return 1;
}

uint32_t audio::input_tap_node::impl::output_bus_count() const {
    return 0;
}
