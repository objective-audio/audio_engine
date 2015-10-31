//
//  yas_audio_tap_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_node.h"
#include "yas_weak.h"

namespace yas
{
    class audio_tap_node : public audio_node
    {
        using super_class = audio_node;

       public:
        class impl;

        audio_tap_node();
        audio_tap_node(std::nullptr_t);

        virtual ~audio_tap_node();

        using render_f = std::function<void(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when)>;

        void set_render_function(const render_f &);

        audio_connection input_connection_on_render(const UInt32 bus_idx) const;
        audio_connection output_connection_on_render(const UInt32 bus_idx) const;
        audio_connection_smap input_connections_on_render() const;
        audio_connection_smap output_connections_on_render() const;
        void render_source(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when);

       protected:
        explicit audio_tap_node(const std::shared_ptr<impl> &);

       private:
        class kernel;

        std::shared_ptr<impl> _impl_ptr() const;
    };

    class audio_input_tap_node : public audio_tap_node
    {
       public:
        class impl;

        audio_input_tap_node();
        audio_input_tap_node(std::nullptr_t);

       private:
        using super_class = audio_tap_node;
    };
}

#include "yas_audio_tap_node_impl.h"
