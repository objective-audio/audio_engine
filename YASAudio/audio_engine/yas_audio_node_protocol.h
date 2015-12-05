//
//  yas_audio_node_protocol.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_connection_protocol.h"

namespace yas
{
    namespace audio
    {
        class engine;
    }

    class audio_node_from_engine
    {
       public:
        virtual ~audio_node_from_engine() = default;

        virtual audio::connection _input_connection(const UInt32 bus_idx) const = 0;
        virtual audio::connection _output_connection(const UInt32 bus_idx) const = 0;
        virtual const audio::connection_wmap &_input_connections() const = 0;
        virtual const audio::connection_wmap &_output_connections() const = 0;
        virtual void _add_connection(const audio::connection &connection) = 0;
        virtual void _remove_connection(const audio::connection &connection) = 0;
        virtual void _set_engine(const audio::engine &engine) = 0;
        virtual audio::engine _engine() const = 0;
        virtual void _update_kernel() = 0;
        virtual void _update_connections() = 0;
    };

    class audio_node_from_connection
    {
       public:
        virtual ~audio_node_from_connection() = default;

        virtual void _add_connection(const audio::connection &connection) = 0;
        virtual void _remove_connection(const audio::connection &connection) = 0;
    };
}