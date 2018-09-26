//
//  yas_audio_tap.cpp
//

#include "yas_audio_engine_tap.h"

using namespace yas;

#pragma mark - audio::tap_kernel

struct audio::engine::tap::kernel : base {
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

#pragma mark - audio::engine::tap::impl

struct audio::engine::tap::impl : base::impl {
    audio::engine::node _node;

    impl(audio::engine::node_args &&args) : _node(std::move(args)) {
    }

    ~impl() = default;

    void prepare(engine::tap const &tap) {
        auto weak_tap = to_weak(tap);

        this->_node.set_render_handler([weak_tap](auto args) {
            if (auto tap = weak_tap.lock()) {
                auto impl_ptr = tap.impl_ptr<impl>();
                if (auto kernel = impl_ptr->_node.kernel()) {
                    impl_ptr->_kernel_on_render = kernel;

                    auto tap_kernel = yas::cast<tap::kernel>(kernel.decorator());
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

        this->_reset_observer = this->_node.chain(node::method::will_reset)
                                    .perform([weak_tap](auto const &) {
                                        if (auto tap = weak_tap.lock()) {
                                            tap.impl_ptr<audio::engine::tap::impl>()->_render_handler = nullptr;
                                        }
                                    })
                                    .end();

        this->_node.set_prepare_kernel_handler([weak_tap](audio::engine::kernel &kernel) {
            if (auto tap = weak_tap.lock()) {
                audio::engine::tap::kernel tap_kernel{};
                tap_kernel.set_render_handler(tap.impl_ptr<audio::engine::tap::impl>()->_render_handler);
                kernel.set_decorator(std::move(tap_kernel));
            }
        });
    }

    void set_render_handler(audio::engine::node::render_f &&func) {
        this->_render_handler = func;

        this->_node.manageable().update_kernel();
    }

    audio::engine::connection input_connection_on_render(uint32_t const bus_idx) {
        return _kernel_on_render.input_connection(bus_idx);
    }

    audio::engine::connection output_connection_on_render(uint32_t const bus_idx) {
        return this->_kernel_on_render.output_connection(bus_idx);
    }

    audio::engine::connection_smap input_connections_on_render() {
        return this->_kernel_on_render.input_connections();
    }

    audio::engine::connection_smap output_connections_on_render() {
        return this->_kernel_on_render.output_connections();
    }

    void render_source(audio::engine::node::render_args &&args) {
        if (auto connection = this->_kernel_on_render.input_connection(args.bus_idx)) {
            if (auto node = connection.source_node()) {
                node.render({.buffer = args.buffer, .bus_idx = connection.source_bus(), .when = args.when});
            }
        }
    }

   private:
    audio::engine::node::render_f _render_handler;
    chaining::any_observer _reset_observer = nullptr;
    audio::engine::kernel _kernel_on_render;
};

#pragma mark - audio::engine::tap

audio::engine::tap::tap() : tap({.is_input = false}) {
}

audio::engine::tap::tap(args args)
    : base(std::make_unique<impl>(args.is_input ? engine::node_args{.input_bus_count = 1, .input_renderable = true} :
                                                  engine::node_args{.input_bus_count = 1, .output_bus_count = 1})) {
    impl_ptr<impl>()->prepare(*this);
}

audio::engine::tap::tap(std::nullptr_t) : base(nullptr) {
}

audio::engine::tap::~tap() = default;

void audio::engine::tap::set_render_handler(audio::engine::node::render_f handler) {
    impl_ptr<impl>()->set_render_handler(std::move(handler));
}

audio::engine::node const &audio::engine::tap::node() const {
    return impl_ptr<impl>()->_node;
}

audio::engine::node &audio::engine::tap::node() {
    return impl_ptr<impl>()->_node;
}

audio::engine::connection audio::engine::tap::input_connection_on_render(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->input_connection_on_render(bus_idx);
}

audio::engine::connection audio::engine::tap::output_connection_on_render(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->output_connection_on_render(bus_idx);
}

audio::engine::connection_smap audio::engine::tap::input_connections_on_render() const {
    return impl_ptr<impl>()->input_connections_on_render();
}

audio::engine::connection_smap audio::engine::tap::output_connections_on_render() const {
    return impl_ptr<impl>()->output_connections_on_render();
}

#if YAS_TEST

void audio::engine::tap::render_source(audio::engine::node::render_args args) {
    impl_ptr<impl>()->render_source(std::move(args));
}

#endif
