//
//  yas_audio_unit_node_protocol.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas
{
    class audio_graph;

    class audio_unit_node_from_engine
    {
       public:
        virtual ~audio_unit_node_from_engine() = default;

        virtual void _prepare_audio_unit() = 0;
        virtual void _prepare_parameters() = 0;
        virtual void _reload_audio_unit() = 0;
    };
}