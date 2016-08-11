//
//  yas_audio_device_io_extension.h
//

#pragma once

#include <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_device_io_extension_protocol.h"
#include "yas_base.h"

namespace yas {
namespace audio {
    class node;
    class device;

    class device_io_extension : public base {
       public:
        class impl;

        device_io_extension();
        device_io_extension(std::nullptr_t);
        device_io_extension(audio::device const &device);

        virtual ~device_io_extension() final;

        void set_device(audio::device const &device);
        audio::device device() const;

        audio::node const &node() const;
        audio::node &node();

        manageable_device_io_extension &manageable();

       private:
        manageable_device_io_extension _manageable = nullptr;
    };
}
}

#endif
