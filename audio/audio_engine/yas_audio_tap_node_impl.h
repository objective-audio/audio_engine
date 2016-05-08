//
//  yas_audio_tap_node_impl.h
//

#pragma once

namespace yas {
namespace audio {
    struct tap_node::impl : node::impl {
        impl();
        virtual ~impl();

        virtual void reset() override;

        virtual UInt32 input_bus_count() const override;
        virtual UInt32 output_bus_count() const override;

        virtual std::shared_ptr<node::kernel> make_kernel() override;
        virtual void prepare_kernel(std::shared_ptr<node::kernel> const &kernel) override;

        void set_render_function(render_f &&);

        audio::connection input_connection_on_render(UInt32 const bus_idx) const;
        audio::connection output_connection_on_render(UInt32 const bus_idx) const;
        audio::connection_smap input_connections_on_render() const;
        audio::connection_smap output_connections_on_render() const;

        virtual void render(audio::pcm_buffer &buffer, UInt32 const bus_idx, audio::time const &when) override;
        void render_source(audio::pcm_buffer &buffer, UInt32 const bus_idx, audio::time const &when);

       private:
        class core;
        std::unique_ptr<core> _core;
    };

    struct input_tap_node::impl : tap_node::impl {
        virtual UInt32 input_bus_count() const override;
        virtual UInt32 output_bus_count() const override;
    };
}
}
