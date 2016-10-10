//
//  yas_audio_engine_device_io.h
//

#pragma once

#include <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_audio_engine_device_io_protocol.h"
#include "yas_base.h"

namespace yas {
namespace audio {
    class device;

    namespace engine {
        class node;

        class device_io : public base {
           public:
            class impl;

            device_io();
            device_io(std::nullptr_t);
            device_io(audio::device const &device);

            virtual ~device_io() final;

            void set_device(audio::device const &device);
            audio::device device() const;

            audio::engine::node const &node() const;
            audio::engine::node &node();

            manageable_device_io &manageable();

           private:
            manageable_device_io _manageable = nullptr;
        };
    }
}
}

#endif
