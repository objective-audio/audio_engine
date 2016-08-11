//
//  yas_audio_unit_extension_protocol.h
//

#pragma once

#include "yas_protocol.h"

namespace yas {
namespace audio {
    struct manageable_unit_extension : protocol {
        struct impl : protocol::impl {
            virtual void prepare_audio_unit() = 0;
            virtual void prepare_parameters() = 0;
            virtual void reload_audio_unit() = 0;
        };

        explicit manageable_unit_extension(std::shared_ptr<impl>);
        manageable_unit_extension(std::nullptr_t);

        void prepare_audio_unit();
        void prepare_parameters();
        void reload_audio_unit();
    };
}
}