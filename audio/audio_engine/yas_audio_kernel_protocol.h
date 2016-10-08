//
//  yas_audio_kernel_protocol.h
//

#pragma once

#include "yas_protocol.h"

namespace yas {
namespace audio {
    struct manageable_kernel : protocol {
        struct impl : protocol::impl {
            virtual void set_input_connections(audio::engine::connection_wmap &&) = 0;
            virtual void set_output_connections(audio::engine::connection_wmap &&) = 0;
        };

        explicit manageable_kernel(std::shared_ptr<impl> &&impl);
        manageable_kernel(std::nullptr_t);

        void set_input_connections(audio::engine::connection_wmap connections);
        void set_output_connections(audio::engine::connection_wmap connections);
    };
}
}
