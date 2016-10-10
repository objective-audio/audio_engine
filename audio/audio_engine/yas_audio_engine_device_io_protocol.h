//
//  yas_audio_engine_device_io_protocol.h
//

#pragma once

#include "yas_protocol.h"

namespace yas {
namespace audio {
    class device_io;

    namespace engine {
        struct manageable_device_io : protocol {
            struct impl : protocol::impl {
                virtual void add_device_io() = 0;
                virtual void remove_device_io() = 0;
                virtual audio::device_io &device_io() = 0;
            };

            explicit manageable_device_io(std::shared_ptr<impl>);
            manageable_device_io(std::nullptr_t);

            void add_device_io();
            void remove_device_io();
            audio::device_io &device_io() const;
        };
    }
}
}
