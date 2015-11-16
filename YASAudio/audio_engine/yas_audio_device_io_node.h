//
//  yas_audio_device_io_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_node.h"
#include "yas_audio_device_io_node_protocol.h"

namespace yas
{
    class audio_device;
    class audio_graph;

    class audio_device_io_node : public audio_node, public audio_device_io_node_from_engine
    {
        using super_class = audio_node;

       public:
        class impl;

        audio_device_io_node();
        audio_device_io_node(std::nullptr_t);
        audio_device_io_node(const audio_device &device);

        virtual ~audio_device_io_node();

        void set_device(const audio_device &device) const;
        audio_device device() const;

       private:
        // from engine
        void _add_device_io() const override;
        void _remove_device_io() const override;
        audio_device_io &_device_io() const override;

       protected:
        audio_device_io_node(const std::shared_ptr<audio_device_io_node::impl> &impl);

#if YAS_TEST
       public:
        class private_access;
        friend private_access;
#endif
    };
}

#include "yas_audio_device_io_node_impl.h"

#if YAS_TEST
#include "yas_audio_device_io_node_private_access.h"
#endif

#endif
