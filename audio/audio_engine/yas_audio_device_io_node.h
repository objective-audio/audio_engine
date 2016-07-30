//
//  yas_audio_device_io_node.h
//

#pragma once

#include <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_device_io_node_protocol.h"
#include "yas_base.h"

namespace yas {
namespace audio {
    class node;
    class device;

    class device_io_node : public base {
       public:
        class impl;

        device_io_node();
        device_io_node(std::nullptr_t);
        device_io_node(audio::device const &device);

        virtual ~device_io_node();

        void set_device(audio::device const &device);
        audio::device device() const;

        audio::node const &node() const;
        audio::node &node();

        manageable_device_io_node &manageable();

       protected:
        device_io_node(std::shared_ptr<device_io_node::impl> const &impl);

       private:
        manageable_device_io_node _manageable = nullptr;
    };
}
}

#include "yas_audio_device_io_node_impl.h"

#endif
