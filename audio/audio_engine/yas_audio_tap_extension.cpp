//
//  yas_audio_tap_extension.cpp
//

#include "yas_audio_tap_extension.h"

using namespace yas;

#pragma mark - audio::tap_kernel

struct audio::tap_extension::kernel : base {
    struct impl : base::impl {
        audio::node::render_f _render_handler;
    };

    kernel() : base(std::make_shared<impl>()) {
    }

    kernel(std::nullptr_t) : base(nullptr) {
    }

    void set_render_handler(audio::node::render_f handler) {
        impl_ptr<impl>()->_render_handler = std::move(handler);
    }

    audio::node::render_f const &render_handler() {
        return impl_ptr<impl>()->_render_handler;
    }
};

#pragma mark - audio::tap_extension::impl

struct audio::tap_extension::impl : base::impl {
    audio::node _node;

    impl(audio::node_args &&args) : _node(std::move(args)) {
    }

    ~impl() = default;

    void prepare(tap_extension const &ext) {
        auto weak_ext = to_weak(ext);

        _node.set_render_handler([weak_ext](auto args) {
            if (auto ext = weak_ext.lock()) {
                auto impl_ptr = ext.impl_ptr<impl>();
                if (auto kernel = impl_ptr->_node.kernel()) {
                    impl_ptr->_kernel_on_render = kernel;

                    auto tap_kernel = yas::cast<tap_extension::kernel>(kernel.extension());
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

        _reset_observer = _node.subject().make_observer(audio::node::method::will_reset, [weak_ext](auto const &) {
            if (auto ext = weak_ext.lock()) {
                ext.impl_ptr<audio::tap_extension::impl>()->_render_handler = nullptr;
            }
        });

        _node.set_prepare_kernel_handler([weak_ext](audio::kernel &kernel) {
            if (auto ext = weak_ext.lock()) {
                audio::tap_extension::kernel tap_kernel{};
                tap_kernel.set_render_handler(ext.impl_ptr<audio::tap_extension::impl>()->_render_handler);
                kernel.set_extension(std::move(tap_kernel));
            }
        });
    }

    void set_render_handler(audio::node::render_f &&func) {
        _render_handler = func;

        _node.manageable().update_kernel();
    }

    audio::connection input_connection_on_render(uint32_t const bus_idx) {
        return _kernel_on_render.input_connection(bus_idx);
    }

    audio::connection output_connection_on_render(uint32_t const bus_idx) {
        return _kernel_on_render.output_connection(bus_idx);
    }

    audio::connection_smap input_connections_on_render() {
        return _kernel_on_render.input_connections();
    }

    audio::connection_smap output_connections_on_render() {
        return _kernel_on_render.output_connections();
    }

    void render_source(audio::node::render_args &&args) {
        if (auto connection = _kernel_on_render.input_connection(args.bus_idx)) {
            if (auto src_node = connection.source_node()) {
                src_node.render({.buffer = args.buffer, .bus_idx = connection.source_bus(), .when = args.when});
            }
        }
    }

   private:
    audio::node::render_f _render_handler;
    audio::node::observer_t _reset_observer;
    audio::kernel _kernel_on_render;
};

#pragma mark - audio::tap_extension

audio::tap_extension::tap_extension() : tap_extension({.is_input = false}) {
}

audio::tap_extension::tap_extension(args args)
    : base(std::make_unique<impl>(std::move(args.is_input ? node_args{.input_bus_count = 1, .input_renderable = true} :
                                                            node_args{.input_bus_count = 1, .output_bus_count = 1}))) {
    impl_ptr<impl>()->prepare(*this);
}

audio::tap_extension::tap_extension(std::nullptr_t) : base(nullptr) {
}

audio::tap_extension::~tap_extension() = default;

void audio::tap_extension::set_render_handler(audio::node::render_f handler) {
    impl_ptr<impl>()->set_render_handler(std::move(handler));
}

audio::node const &audio::tap_extension::node() const {
    return impl_ptr<impl>()->_node;
}

audio::node &audio::tap_extension::node() {
    return impl_ptr<impl>()->_node;
}

audio::connection audio::tap_extension::input_connection_on_render(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->input_connection_on_render(bus_idx);
}

audio::connection audio::tap_extension::output_connection_on_render(uint32_t const bus_idx) const {
    return impl_ptr<impl>()->output_connection_on_render(bus_idx);
}

audio::connection_smap audio::tap_extension::input_connections_on_render() const {
    return impl_ptr<impl>()->input_connections_on_render();
}

audio::connection_smap audio::tap_extension::output_connections_on_render() const {
    return impl_ptr<impl>()->output_connections_on_render();
}

#if YAS_TEST

void audio::tap_extension::render_source(audio::node::render_args args) {
    impl_ptr<impl>()->render_source(std::move(args));
}

#endif
