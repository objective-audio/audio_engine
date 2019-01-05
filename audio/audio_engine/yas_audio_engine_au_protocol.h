//
//  yas_audio_engine_au_protocol.h
//

#pragma once

#include <cpp_utils/yas_protocol.h>

namespace yas::audio::engine {
struct manageable_au : protocol {
    struct impl : protocol::impl {
        virtual void prepare_unit() = 0;
        virtual void prepare_parameters() = 0;
        virtual void reload_unit() = 0;
    };

    explicit manageable_au(std::shared_ptr<impl>);
    manageable_au(std::nullptr_t);

    void prepare_unit();
    void prepare_parameters();
    void reload_unit();
};
}  // namespace yas::audio::engine
