//
//  yas_audio_node_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#if YAS_TEST

#include "yas_audio_engine.h"

namespace yas
{
    class audio_node::private_access
    {
       public:
        static audio_node create()
        {
            return audio_node(std::make_shared<audio_node::impl>());
        }

        static audio::connection input_connection(const audio_node &node, const UInt32 bus_idx)
        {
            return node._input_connection(bus_idx);
        }

        static audio::connection output_connection(const audio_node &node, const UInt32 bus_idx)
        {
            return node._output_connection(bus_idx);
        }

        static const audio::connection_wmap &input_connections(const audio_node &node)
        {
            return node._input_connections();
        }

        static const audio::connection_wmap &output_connections(const audio_node &node)
        {
            return node._output_connections();
        }

        static void add_connection(audio_node &node, const audio::connection &connection)
        {
            node._add_connection(connection);
        }

        static void remove_connection(audio_node &node, const audio::connection &connection)
        {
            node.impl_ptr<impl>()->remove_connection(connection);
        }

        static void set_engine(audio_node &node, const audio_engine &engine)
        {
            node._set_engine(engine);
        }

        static void update_kernel(audio_node &node)
        {
            node.impl_ptr<impl>()->update_kernel();
        }

        static std::shared_ptr<kernel> kernel(const audio_node &node)
        {
            return node.impl_ptr<impl>()->kernel_cast();
        }
    };
}

#endif
