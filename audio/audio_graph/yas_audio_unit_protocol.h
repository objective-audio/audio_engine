//
//  yas_audio_unit_protocol.h
//

#pragma once

#include "yas_protocol.h"

namespace yas {
namespace audio {
    struct manageable_unit : protocol {
        struct impl : protocol::impl {
            virtual void initialize() = 0;
            virtual void uninitialize() = 0;
            virtual void set_graph_key(std::experimental::optional<uint8_t> const &) = 0;
            virtual std::experimental::optional<uint8_t> const &graph_key() const = 0;
            virtual void set_key(std::experimental::optional<uint16_t> const &) = 0;
            virtual std::experimental::optional<uint16_t> const &key() const = 0;
        };

        explicit manageable_unit(std::shared_ptr<impl> impl) : protocol(impl) {
        }

        void initialize() {
            impl_ptr<impl>()->initialize();
        }

        void uninitialize() {
            impl_ptr<impl>()->uninitialize();
        }

        void set_graph_key(std::experimental::optional<uint8_t> const &key) {
            impl_ptr<impl>()->set_graph_key(key);
        }

        std::experimental::optional<uint8_t> const &graph_key() const {
            return impl_ptr<impl>()->graph_key();
        }

        void set_key(std::experimental::optional<uint16_t> const &key) {
            impl_ptr<impl>()->set_key(key);
        }

        std::experimental::optional<uint16_t> const &key() const {
            return impl_ptr<impl>()->key();
        }
    };
}
}
