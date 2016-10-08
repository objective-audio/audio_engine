//
//  yas_audio_tap_node.cpp
//

#include "yas_audio_tap_node.h"

using namespace yas;

#pragma mark - audio::tap_kernel

struct audio::tap_node::kernel : base {
    struct impl : base::impl {
        audio::engine::node::render_f _render_handler;
    };

    kernel() : base(std::make_shared<impl>()) {
    }

    kernel(std::nullptr_t) : base(nullptr) {
    }

    void set_render_handler(audio::engine::node::render_f handler) {
        impl_ptr<impl>()->_render_handler = std::move(handler);
    }

    audio::engine::node::render_f const &render_handler() {
        return impl_ptr<impl>()->_render_handler;
    }
};

#pragma mark - audio::tap_node::impl

struct audio::tap_node::impl : base::impl {
    audio::engine::node _node;

    impl(audio::engine::node_args &&args) : _node(std::move(args)) {
    }

    ~impl() = default;

    void prepare(tap_node const &node) {
        auto weak_node = to_weak(node);

        _node.set_render_handler([weak_node](auto args) {
            if (auto node = weak_node.lock()) {
                auto impl_ptr = node.impl_ptr<impl>();
                if (auto kernel = impl_ptr->_node.kernel()) {
                    impl_ptr->_kernel_on_render = kernel;

                    auto tap_kernel = yas::cast<tap_node::kernel>(kernel.decorator());
                    auto const &handler = tap_kernel.render_handler();

                    if (handler) {
                        handler(args);
                    } else {
                        impl_ptr->render_source(std::move(args));
                    }

                    impl_ptr->_kernel_on_render = nullptr;
                }
            }
        });

        _reset_observer = _node.subject().make_observer(audio::engine::node::method::will_reset, [weak_node](auto const &) {
            if (auto node = weak_node.lock()) {
                node.impl_ptr<audio::tap_node::impl>()->_render_handler = nullptr;
            }
        });

        _node.set_prepare_kernel_handler([weak_node](audio::engine::kernel &kernel) {
            if (auto node = weak_node.lock()) {
                audio::tap_node::kernel tap_kernel{};
                tap_kernel.set_render_handler(node.impl_ptr<audio::tap_node::impl>()->_render_handler);
                kernel.set_decorator(std::move(tap_kernel));
            }
        });
    }

    void set_render_handler(audio::engine::node::render_f &&func) {
        _render_handler = func;

        _node.manageable().update_kernel();
    }

    audio::engine::connection input_connection_on_render(uint32_t const bus_idx) {
        return _kernel_on_render.input_connection(bus_idx);
    }

    audio::engine::connection output_connection_on_render(uint32_t const bus_idx) {
        return _kernel_on_render.output_connection(bus_idx);
    }

    audio::engine::connection_smap input_connections_on_render() {
        return _kernel_on_render.input_connections();
    }

    audio::engine::connection_smap output_connections_on_render() {
        return _kernel_on_render.output_connections();
    }

    void render_source(audio::engine::node::render_args &&args) {
        if (auto connection = _kernel_on_render.input_connection(args.bus_idx)) {
            if (auto node = connection.source_node()) {
                node.render({.buffer = args.buffer, .bus_idx = connection.source_bus(), .when = args.when});
            }
        }
    }

   private:
    audio::engine::node::render_f _render_handler;
    audio::engine::node::observer_t _reset_observer;
    audio::engine::kernel _kernel_on_render;
};

#pragma mark - audio::tap_node

audio::tap_node::tap_node() : tap_node({.is_input = false}) {
}

audio::tap_node::tap_node(args args)
: base(std::make_unique<impl>(args.is_input ? engine::node_args{.input_bus_count = 1, .input_renderable = true} :
                              engine::node_args{.input_bus_count = 1, .output_bus_count = 1})) {
    impl_ptr<impl>()->prepare(*this);
}

audio::tap_node::tap_node(std::nullptr_t) : base(nullptr) {
}

audio::tap_node::~tap_node() = default;

void audio::tap_node::set_render_handler(audio::engine::node::render_f handler) {
    impl_ptr<impl>()->set_render_handler(std::move(handler));
}

audio::engine::node const &audio::tap_node::node() const {
    return impl_ptr<impl>()->_node;
}

audio::engine::node &audio::tap_node::node() {
    return impl_ptr<impl>()->_node;
}

audio::engine::connection audio::tap_node::input_connection_on_render(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->input_connection_on_render(bus_idx);
}

audio::engine::connection audio::tap_node::output_connection_on_render(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->output_connection_on_render(bus_idx);
}

audio::engine::connection_smap audio::tap_node::input_connections_on_render() const {
    return impl_ptr<impl>()->input_connections_on_render();
}

audio::engine::connection_smap audio::tap_node::output_connections_on_render() const {
    return impl_ptr<impl>()->output_connections_on_render();
}

#if YAS_TEST

void audio::tap_node::render_source(audio::engine::node::render_args args) {
    impl_ptr<impl>()->render_source(std::move(args));
}

#endif
