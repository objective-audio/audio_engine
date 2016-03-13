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
            virtual void set_graph_key(std::experimental::optional<UInt8> const &key) = 0;
            virtual std::experimental::optional<UInt8> const &graph_key() const = 0;
            virtual void set_key(std::experimental::optional<UInt16> const &key) = 0;
            virtual std::experimental::optional<UInt16> const &key() const = 0;
        };

        explicit manageable_unit(std::shared_ptr<impl> impl) : protocol(impl) {
        }

        void initialize() {
            impl_ptr<impl>()->initialize();
        }

        void uninitialize() {
            impl_ptr<impl>()->uninitialize();
        }

        void set_graph_key(std::experimental::optional<UInt8> const &key) {
            impl_ptr<impl>()->set_graph_key(key);
        }

        std::experimental::optional<UInt8> const &graph_key() const {
            return impl_ptr<impl>()->graph_key();
        }

        void set_key(std::experimental::optional<UInt16> const &key) {
            impl_ptr<impl>()->set_key(key);
        }

        std::experimental::optional<UInt16> const &key() const {
            return impl_ptr<impl>()->key();
        }
    };
}
}
