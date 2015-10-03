//
//  yas_audio_device_io_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_node.h"
#include <set>

namespace yas
{
    class audio_device_io_node : public audio_node
    {
       public:
        static audio_device_io_node_sptr create(const audio_device_sptr &device = nullptr);

        virtual ~audio_device_io_node();

        virtual UInt32 input_bus_count() const override;
        virtual UInt32 output_bus_count() const override;

        void set_device(const audio_device_sptr &device);
        audio_device_sptr device() const;

        virtual void render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when) override;

       protected:
        audio_device_io_node(const audio_device_sptr &device);

        virtual void update_connections() override;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        using super_class = audio_node;

        void _add_device_io_to_graph(const audio_graph_sptr &graph);
        void _remove_device_io_from_graph();
        bool _validate_connections() const;

       public:
        class private_access;
        friend private_access;
    };
}

#include "yas_audio_device_io_node_private_access.h"

#endif