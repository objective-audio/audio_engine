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

        using render_function =
            std::function<void(const pcm_buffer_sptr &buffer, const uint32_t bus_idx, const audio_time_sptr &when)>;

        void set_render_function(const render_function &);

        virtual uint32_t input_bus_count() const override;
        virtual uint32_t output_bus_count() const override;

        virtual void render(const pcm_buffer_sptr &buffer, const uint32_t bus_idx, const audio_time_sptr &when) override;

        audio_connection_sptr input_connection_on_render(const uint32_t bus_idx) const;
        audio_connection_sptr output_connection_on_render(const uint32_t bus_idx) const;
        audio_connection_wmap &input_connections_on_render() const;
        audio_connection_wmap &output_connections_on_render() const;
        void render_source(const pcm_buffer_sptr &buffer, const uint32_t bus_idx, const audio_time_sptr &when);

       protected:
        audio_tap_node();

        virtual audio_node_core_ptr make_node_core() override;
        virtual void prepare_node_core(const audio_node_core_ptr &node_core) override;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        using super_class = audio_node;
    };

    class audio_input_tap_node : public audio_tap_node
    {
       public:
        static audio_input_tap_node_sptr create();

        virtual uint32_t input_bus_count() const override;
        virtual uint32_t output_bus_count() const override;
    };
}
