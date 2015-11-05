//
//  yas_audio_device_io_node_protocol.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas
{
    class audio_device_io_node_from_engine
    {
       public:
        virtual ~audio_device_io_node_from_engine() = default;

        virtual void _add_audio_device_io_to_graph(audio_graph &graph) = 0;
        virtual void _remove_audio_device_io_from_graph() = 0;
    };
}
