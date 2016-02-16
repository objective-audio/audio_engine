//
//  yas_audio_device_io_node.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_device_io_node_protocol.h"
#include "yas_audio_node.h"

namespace yas {
namespace audio {
    class device;

    class device_io_node : public node, public device_io_node_from_engine {
        using super_class = node;

       public:
        class impl;

        device_io_node();
        device_io_node(std::nullptr_t);
        device_io_node(audio::device const &device);

        virtual ~device_io_node();

        void set_device(audio::device const &device);
        audio::device device() const;

       private:
        // from engine
        void _add_device_io() override;
        void _remove_device_io() override;
        audio::device_io &_device_io() const override;

       protected:
        device_io_node(std::shared_ptr<device_io_node::impl> const &impl);

#if YAS_TEST
       public:
        class private_access;
        friend private_access;
#endif
    };
}
}

#include "yas_audio_device_io_node_impl.h"

#if YAS_TEST
#include "yas_audio_device_io_node_private_access.h"
#endif

#endif
