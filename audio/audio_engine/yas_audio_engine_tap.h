//
//  yas_audio_tap.h
//

#pragma once

#include "yas_audio_engine_node.h"

namespace yas::audio::engine {
struct tap : std::enable_shared_from_this<tap> {
    struct args {
        bool is_input = false;
    };

    virtual ~tap();

    void set_render_handler(audio::engine::node::render_f);

    audio::engine::node const &node() const;
    audio::engine::node &node();

    std::shared_ptr<audio::engine::connection> input_connection_on_render(uint32_t const bus_idx) const;
    std::shared_ptr<audio::engine::connection> output_connection_on_render(uint32_t const bus_idx) const;
    audio::engine::connection_smap input_connections_on_render() const;
    audio::engine::connection_smap output_connections_on_render() const;

    // for Test
    void render_source(audio::engine::node::render_args args);

   private:
    class kernel;

    std::shared_ptr<audio::engine::node> _node;
    audio::engine::node::render_f _render_handler;
    chaining::any_observer_ptr _reset_observer = nullptr;
    std::shared_ptr<audio::engine::kernel> _kernel_on_render;

    explicit tap(args);

    void _prepare();

    tap(tap const &) = delete;
    tap(tap &&) = delete;
    tap &operator=(tap const &) = delete;
    tap &operator=(tap &&) = delete;

   public:
    static std::shared_ptr<tap> make_shared();
    static std::shared_ptr<tap> make_shared(tap::args);
};
}  // namespace yas::audio::engine
