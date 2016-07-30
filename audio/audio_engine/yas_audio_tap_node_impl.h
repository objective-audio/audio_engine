//
//  yas_audio_tap_node_impl.h
//

#pragma once

namespace yas {
namespace audio {
    struct tap_node::impl : node::impl {
        impl();
        virtual ~impl();

        void prepare(tap_node const &);

        void set_render_function(render_f &&);

        audio::connection input_connection_on_render(uint32_t const bus_idx) const;
        audio::connection output_connection_on_render(uint32_t const bus_idx) const;
        audio::connection_smap input_connections_on_render() const;
        audio::connection_smap output_connections_on_render() const;

        void render_source(audio::pcm_buffer &buffer, uint32_t const bus_idx, audio::time const &when);

       private:
        class core;
        std::unique_ptr<core> _core;

        void _will_reset();
        void _did_prepare_kernel(node::kernel const &kernel);
    };

    struct input_tap_node::impl : tap_node::impl {
        impl();
    };
}
}
