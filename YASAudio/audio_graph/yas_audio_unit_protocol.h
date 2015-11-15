//
//  yas_audio_unit_protocol.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas
{
    class audio_unit_from_graph
    {
       public:
        virtual ~audio_unit_from_graph() = default;

        virtual void _initialize() const = 0;
        virtual void _uninitialize() const = 0;
        virtual void _set_graph_key(const std::experimental::optional<UInt8> &key) const = 0;
        virtual const std::experimental::optional<UInt8> &_graph_key() const = 0;
        virtual void _set_key(const std::experimental::optional<UInt16> &key) const = 0;
        virtual const std::experimental::optional<UInt16> &_key() const = 0;
    };
}
