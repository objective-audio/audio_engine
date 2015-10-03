//
//  yas_audio_tap_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_node.h"

namespace yas
{
    class audio_tap_node : public audio_node
    {
       public:
        static audio_tap_node_sptr create();

        virtual ~audio_tap_node();

        using render_f = std::function<void(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when)>;

        void set_render_function(const render_f &);

        virtual UInt32 input_bus_count() const override;
        virtual UInt32 output_bus_count() const override;

        virtual void render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when) override;

        audio_connection_sptr input_connection_on_render(const UInt32 bus_idx) const;
        audio_connection_sptr output_connection_on_render(const UInt32 bus_idx) const;
        audio_connection_smap input_connections_on_render() const;
        audio_connection_smap output_connections_on_render() const;
        void render_source(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when);

       protected:
        audio_tap_node();

        virtual audio_node_core_sptr make_node_core() override;
        virtual void prepare_node_core(const audio_node_core_sptr &node_core) override;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        using super_class = audio_node;
    };

    class audio_input_tap_node : public audio_tap_node
    {
       public:
        static audio_input_tap_node_sptr create();

        virtual UInt32 input_bus_count() const override;
        virtual UInt32 output_bus_count() const override;
    };
}
