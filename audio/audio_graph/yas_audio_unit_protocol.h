//
//  yas_audio_unit_protocol.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas {
namespace audio {
    class unit_from_graph {
       public:
        virtual ~unit_from_graph() = default;

        virtual void _initialize() = 0;
        virtual void _uninitialize() = 0;
        virtual void _set_graph_key(const std::experimental::optional<UInt8> &key) = 0;
        virtual const std::experimental::optional<UInt8> &_graph_key() const = 0;
        virtual void _set_key(const std::experimental::optional<UInt16> &key) = 0;
        virtual const std::experimental::optional<UInt16> &_key() const = 0;
    };
}
}
