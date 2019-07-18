//
//  yas_audio_tap.cpp
//

#include "yas_audio_engine_tap.h"

using namespace yas;

#pragma mark - audio::tap_kernel

struct audio::engine::tap::kernel {
    kernel() {
    }

    audio::engine::node::render_f render_handler = nullptr;

   private:
    kernel(kernel const &) = delete;
    kernel(kernel &&) = delete;
    kernel &operator=(kernel const &) = delete;
    kernel &operator=(kernel &&) = delete;
};

#pragma mark - audio::engine::tap

audio::engine::tap::tap(args args)
    : _node(make_node(args.is_input ? engine::node_args{.input_bus_count = 1, .input_renderable = true} :
                                      engine::node_args{.input_bus_count = 1, .output_bus_count = 1})) {
}

void audio::engine::tap::prepare() {
    auto weak_tap = to_weak(shared_from_this());

    this->_node->set_render_handler([weak_tap](auto args) {
        if (auto tap = weak_tap.lock()) {
            if (auto kernel = tap->_node->kernel()) {
                tap->_kernel_on_render = kernel;

                auto tap_kernel = std::any_cast<std::shared_ptr<tap::kernel>>(kernel->decorator);
                auto const &handler = tap_kernel->render_handler;

                if (handler) {
                    handler(args);
                } else {
                    tap->render_source(std::move(args));
                }

                tap->_kernel_on_render = nullptr;
            }
        }
    });

    this->_reset_observer = this->_node->chain(node::method::will_reset)
                                .perform([weak_tap](auto const &) {
                                    if (auto tap = weak_tap.lock()) {
                                        tap->_render_handler = nullptr;
                                    }
                                })
                                .end();

    this->_node->set_prepare_kernel_handler([weak_tap](audio::engine::kernel &kernel) {
        if (auto tap = weak_tap.lock()) {
            auto tap_kernel = std::make_shared<audio::engine::tap::kernel>();
            tap_kernel->render_handler = tap->_render_handler;
            kernel.decorator = std::move(tap_kernel);
        }
    });
}

void audio::engine::tap::set_render_handler(audio::engine::node::render_f handler) {
    this->_render_handler = handler;

    this->_node->manageable()->update_kernel();
}

audio::engine::node const &audio::engine::tap::node() const {
    return *this->_node;
}

audio::engine::node &audio::engine::tap::node() {
    return *this->_node;
}

std::shared_ptr<audio::engine::connection> audio::engine::tap::input_connection_on_render(
    uint32_t const bus_idx) const {
    return this->_kernel_on_render->input_connection(bus_idx);
}

std::shared_ptr<audio::engine::connection> audio::engine::tap::output_connection_on_render(
    uint32_t const bus_idx) const {
    return this->_kernel_on_render->output_connection(bus_idx);
}

audio::engine::connection_smap audio::engine::tap::input_connections_on_render() const {
    return this->_kernel_on_render->input_connections();
}

audio::engine::connection_smap audio::engine::tap::output_connections_on_render() const {
    return this->_kernel_on_render->output_connections();
}

void audio::engine::tap::render_source(audio::engine::node::render_args args) {
    if (auto connection = this->_kernel_on_render->input_connection(args.bus_idx)) {
        if (auto node = connection->source_node()) {
            node->render({.buffer = args.buffer, .bus_idx = connection->source_bus, .when = args.when});
        }
    }
}

#pragma mark - factory

namespace yas::audio::engine {
struct tap_factory : tap {
    tap_factory(tap::args &&args) : tap(std::move(args)) {
    }

    void prepare() {
        this->tap::prepare();
    }
};
}  // namespace yas::audio::engine

std::shared_ptr<audio::engine::tap> audio::engine::make_tap() {
    return make_tap({.is_input = false});
}

std::shared_ptr<audio::engine::tap> audio::engine::make_tap(tap::args args) {
    auto shared = std::make_shared<audio::engine::tap_factory>(std::move(args));
    shared->prepare();
    return shared;
}
