//
//  yas_audio_node_protocol.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_connection_protocol.h"

namespace yas
{
    class audio_engine;
    class audio_graph;

    class audio_node_from_engine
    {
       public:
        virtual ~audio_node_from_engine() = default;

        virtual audio_connection _input_connection(const UInt32 bus_idx) const = 0;
        virtual audio_connection _output_connection(const UInt32 bus_idx) const = 0;
        virtual const audio_connection_wmap &_input_connections() const = 0;
        virtual const audio_connection_wmap &_output_connections() const = 0;
        virtual void _add_connection(const audio_connection &connection) = 0;
        virtual void _remove_connection(const audio_connection &connection) = 0;
        virtual void _set_engine(const audio_engine &engine) = 0;
        virtual audio_engine _engine() = 0;
        virtual void _update_kernel() = 0;
        virtual void _update_connections() = 0;
    };

    class audio_node_from_connection
    {
       public:
        virtual ~audio_node_from_connection() = default;

        virtual void _add_connection(const audio_connection &connection) = 0;
        virtual void _remove_connection(const audio_connection &connection) = 0;
    };
}