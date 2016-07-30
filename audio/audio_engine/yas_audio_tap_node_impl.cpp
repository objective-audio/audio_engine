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
    audio::node::observer_t _reset_observer;
    audio::node::kernel_observer_t _kernel_observer;
};

audio::tap_node::impl::impl() : node::impl(), _core(std::make_unique<core>()) {
    set_input_bus_count(1);
    set_output_bus_count(1);
}

audio::tap_node::impl::~impl() = default;

void audio::tap_node::impl::prepare(tap_node const &node) {
    set_make_kernel_handler([]() { return audio::tap_node::kernel{}; });

    auto weak_node = to_weak(node);

    audio::node::impl::set_render_handler(
        [weak_node](audio::pcm_buffer &buffer, uint32_t const bus_idx, audio::time const &when) {
            if (auto node = weak_node.lock()) {
                auto impl_ptr = node.impl_ptr<impl>();
                if (auto kernel = impl_ptr->kernel_cast<tap_node::kernel>()) {
                    impl_ptr->_core->kernel_on_render = kernel;

                    auto const &render_function = kernel.render_function();

                    if (render_function) {
                        render_function(buffer, bus_idx, when);
                    } else {
                        impl_ptr->render_source(buffer, bus_idx, when);
                    }

                    impl_ptr->_core->kernel_on_render = nullptr;
                }
            }
        });

    _core->_reset_observer = subject().make_observer(audio::node::method::will_reset, [weak_node](auto const &) {
        if (auto node = weak_node.lock()) {
            node.impl_ptr<audio::tap_node::impl>()->_will_reset();
        }
    });

    _core->_kernel_observer =
        kernel_subject().make_observer(audio::node::kernel_method::did_prepare, [weak_node](auto const &context) {
            if (auto node = weak_node.lock()) {
                node.impl_ptr<audio::tap_node::impl>()->_did_prepare_kernel(context.value);
            }
        });
}

void audio::tap_node::impl::_will_reset() {
    _core->render_function = nullptr;
}

void audio::tap_node::impl::_did_prepare_kernel(audio::node::kernel const &kernel) {
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

void audio::tap_node::impl::render_source(pcm_buffer &buffer, uint32_t const bus_idx, time const &when) {
    if (auto connection = _core->kernel_on_render.input_connection(bus_idx)) {
        if (auto node = connection.source_node()) {
            node.render(buffer, connection.source_bus(), when);
        }
    }
}

#pragma mark - input_tap_node

audio::input_tap_node::impl::impl() {
    set_input_bus_count(1);
    set_output_bus_count(0);
}
