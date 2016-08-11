//
//  yas_audio_device_io_extension_protocol.h
//

#pragma once

#include "yas_protocol.h"

namespace yas {
namespace audio {
    class device_io;

    struct manageable_device_io_extension : protocol {
        struct impl : protocol::impl {
            virtual void add_device_io() = 0;
            virtual void remove_device_io() = 0;
            virtual audio::device_io &device_io() = 0;
        };

        explicit manageable_device_io_extension(std::shared_ptr<impl>);
        manageable_device_io_extension(std::nullptr_t);

        void add_device_io();
        void remove_device_io();
        audio::device_io &device_io() const;
    };
}
}
