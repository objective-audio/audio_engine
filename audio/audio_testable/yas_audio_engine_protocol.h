//
//  yas_audio_engine_protocol.h
//

#pragma once

#include "yas_protocol.h"

namespace yas {
namespace audio {
    struct testable_engine : protocol {
        struct impl : protocol::impl {
            virtual std::unordered_set<node> &nodes() const = 0;
            virtual audio::connection_set &connections() const = 0;
        };

        explicit testable_engine(std::shared_ptr<impl> &&impl) : protocol(std::move(impl)) {
        }

        std::unordered_set<node> &nodes() const {
            return impl_ptr<impl>()->nodes();
        }

        audio::connection_set &connections() const {
            return impl_ptr<impl>()->connections();
        }
    };
}
}
