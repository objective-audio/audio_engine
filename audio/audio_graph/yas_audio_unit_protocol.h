//
//  yas_audio_unit_protocol.h
//

#pragma once

namespace yas {
namespace audio {
    class manageable_unit {
       public:
        virtual ~manageable_unit() = default;

        virtual void _initialize() = 0;
        virtual void _uninitialize() = 0;
        virtual void _set_graph_key(std::experimental::optional<UInt8> const &key) = 0;
        virtual std::experimental::optional<UInt8> const &_graph_key() const = 0;
        virtual void _set_key(std::experimental::optional<UInt16> const &key) = 0;
        virtual std::experimental::optional<UInt16> const &_key() const = 0;
    };
}
}
