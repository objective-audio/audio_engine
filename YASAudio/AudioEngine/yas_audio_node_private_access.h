//
//  yas_audio_node_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_engine.h"

namespace yas
{
    class audio_node::kernel::private_access
    {
       public:
        static void set_input_connections(const std::shared_ptr<kernel> &kernel,
                                          const audio_connection_wmap &connections)
        {
            kernel->_set_input_connections(connections);
        }

        static void set_output_connections(const std::shared_ptr<kernel> &kernel,
                                           const audio_connection_wmap &connections)
        {
            kernel->_set_output_connections(connections);
        }
    };

    class audio_node::private_access
    {
       public:
        static audio_node create()
        {
            return audio_node(std::make_unique<audio_node::impl>(), create_tag);
        }

        static std::shared_ptr<audio_node::impl> impl(const audio_node &node)
        {
            return node._impl;
        }

        static audio_connection input_connection(const audio_node &node, const UInt32 bus_idx)
        {
            return node.input_connection(bus_idx);
        }

        static audio_connection output_connection(const audio_node &node, const UInt32 bus_idx)
        {
            return node.output_connection(bus_idx);
        }

        static const audio_connection_wmap &input_connections(const audio_node &node)
        {
            return node.input_connections();
        }

        static const audio_connection_wmap &output_connections(const audio_node &node)
        {
            return node.output_connections();
        }

        static void add_connection(audio_node &node, const audio_connection &connection)
        {
            node._impl->add_connection(connection);
        }

        static void remove_connection(audio_node &node, const audio_connection &connection)
        {
            node._impl->remove_connection(connection);
        }

        static void set_engine(audio_node &node, const audio_engine &engine)
        {
            node._impl->set_engine(engine);
        }

        static audio_engine engine(const audio_node &node)
        {
            return node.engine();
        }

        static void update_kernel(audio_node &node)
        {
            node._impl->update_kernel();
        }

        static std::shared_ptr<kernel> kernel(const audio_node &node)
        {
            return node._impl->kernel_cast();
        }

        static void update_connections(audio_node &node)
        {
            node._impl->update_connections();
        }
    };
}
