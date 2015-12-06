//
//  yas_audio_node_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#if YAS_TEST

#include "yas_audio_engine.h"

namespace yas
{
    namespace audio
    {
        class node::private_access
        {
           public:
            static node create()
            {
                return node(std::make_shared<node::impl>());
            }

            static audio::connection input_connection(const node &node, const UInt32 bus_idx)
            {
                return node._input_connection(bus_idx);
            }

            static audio::connection output_connection(const node &node, const UInt32 bus_idx)
            {
                return node._output_connection(bus_idx);
            }

            static const audio::connection_wmap &input_connections(const node &node)
            {
                return node._input_connections();
            }

            static const audio::connection_wmap &output_connections(const node &node)
            {
                return node._output_connections();
            }

            static void add_connection(node &node, const audio::connection &connection)
            {
                node._add_connection(connection);
            }

            static void remove_connection(node &node, const audio::connection &connection)
            {
                node.impl_ptr<impl>()->remove_connection(connection);
            }

            static void set_engine(node &node, const audio::engine &engine)
            {
                node._set_engine(engine);
            }

            static void update_kernel(node &node)
            {
                node.impl_ptr<impl>()->update_kernel();
            }

            static std::shared_ptr<kernel> kernel(const node &node)
            {
                return node.impl_ptr<impl>()->kernel_cast();
            }
        };
    }
}

#endif
