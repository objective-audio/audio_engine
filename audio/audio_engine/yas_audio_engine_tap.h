//
//  yas_audio_tap.h
//

#pragma once

#include "yas_audio_engine_node.h"

namespace yas {
namespace audio {
    namespace engine {
        class tap : public base {
           public:
            class kernel;
            class impl;

            struct args {
                bool is_input = false;
            };

            tap();
            tap(args);
            tap(std::nullptr_t);

            virtual ~tap() final;

            void set_render_handler(audio::engine::node::render_f);

            audio::engine::node const &node() const;
            audio::engine::node &node();

            audio::engine::connection input_connection_on_render(uint32_t const bus_idx) const;
            audio::engine::connection output_connection_on_render(uint32_t const bus_idx) const;
            audio::engine::connection_smap input_connections_on_render() const;
            audio::engine::connection_smap output_connections_on_render() const;

#if YAS_TEST
            void render_source(audio::engine::node::render_args args);
#endif
        };
    }
}
}
