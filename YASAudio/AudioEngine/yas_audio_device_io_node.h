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
    class audio_device;
    class audio_graph;

    class audio_device_io_node : public audio_node
    {
       public:
        static audio_device_io_node_sptr create();
        static audio_device_io_node_sptr create(const audio_device &device);

        virtual ~audio_device_io_node();

        void set_device(const audio_device &device);
        audio_device device() const;

        virtual void render(audio_pcm_buffer &buffer, const UInt32 bus_idx, const audio_time &when) override;

       protected:
        audio_device_io_node(const audio_device &device);

       private:
        using super_class = audio_node;
        class impl;

        impl *_impl_ptr() const;

        void _add_device_io_to_graph(audio_graph &graph);
        void _remove_device_io_from_graph();

       public:
        class private_access;
        friend private_access;
    };
}

#include "yas_audio_device_io_node_private_access.h"

#endif