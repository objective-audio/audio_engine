//
//  yas_audio_tap_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_node.h"

namespace yas {
namespace audio {
    class tap_node : public node {
        using super_class = node;

       public:
        class kernel;
        class impl;

        tap_node();
        tap_node(std::nullptr_t);

        virtual ~tap_node();

        using render_f = std::function<void(audio::pcm_buffer &buffer, const UInt32 bus_idx, const audio::time &when)>;

        void set_render_function(const render_f &);

        audio::connection input_connection_on_render(const UInt32 bus_idx) const;
        audio::connection output_connection_on_render(const UInt32 bus_idx) const;
        audio::connection_smap input_connections_on_render() const;
        audio::connection_smap output_connections_on_render() const;
        void render_source(audio::pcm_buffer &buffer, const UInt32 bus_idx, const audio::time &when);

       protected:
        explicit tap_node(const std::shared_ptr<impl> &);
    };

    class input_tap_node : public tap_node {
       public:
        class impl;

        input_tap_node();
        input_tap_node(std::nullptr_t);

       private:
        using super_class = tap_node;
    };
}
}

#include "yas_audio_tap_node_impl.h"