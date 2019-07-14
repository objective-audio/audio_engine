//
//  yas_audio_tap.h
//

#pragma once

#include "yas_audio_engine_node.h"

namespace yas::audio::engine {
class tap final : public base {
   public:
    class kernel;
    class impl;

    struct args {
        bool is_input = false;
    };

    tap();
    tap(args);
    tap(std::nullptr_t);

    virtual ~tap();

    void set_render_handler(audio::engine::node::render_f);

    std::shared_ptr<audio::engine::node> const &node() const;
    std::shared_ptr<audio::engine::node> &node();

    audio::engine::connection input_connection_on_render(uint32_t const bus_idx) const;
    audio::engine::connection output_connection_on_render(uint32_t const bus_idx) const;
    audio::engine::connection_smap input_connections_on_render() const;
    audio::engine::connection_smap output_connections_on_render() const;

    // for Test
    void render_source(audio::engine::node::render_args args);
};
}  // namespace yas::audio::engine
