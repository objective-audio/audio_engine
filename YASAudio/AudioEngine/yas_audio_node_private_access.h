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
        static void set_input_connections(const kernel_sptr &kernel, const audio_connection_wmap &connections)
        {
            kernel->_set_input_connections(connections);
        }

        static void set_output_connections(const kernel_sptr &kernel, const audio_connection_wmap &connections)
        {
            kernel->_set_output_connections(connections);
        }
    };

    class audio_node::private_access
    {
       public:
        static audio_node_sptr create()
        {
            return audio_node_sptr(new audio_node(std::make_unique<audio_node::impl>()));
        }

        static audio_connection input_connection(const audio_node_sptr &node, const UInt32 bus_idx)
        {
            return node->input_connection(bus_idx);
        }

        static audio_connection output_connection(const audio_node_sptr &node, const UInt32 bus_idx)
        {
            return node->output_connection(bus_idx);
        }

        static const audio_connection_wmap &input_connections(const audio_node_sptr &node)
        {
            return node->input_connections();
        }

        static const audio_connection_wmap &output_connections(const audio_node_sptr &node)
        {
            return node->output_connections();
        }

        static void add_connection(const audio_node_sptr &node, const audio_connection &connection)
        {
            node->_add_connection(connection);
        }

        static void remove_connection(const audio_node_sptr &node, const audio_connection &connection)
        {
            node->_remove_connection(connection);
        }

        static void set_engine(const audio_node_sptr &node, const audio_engine &engine)
        {
            node->_set_engine(engine);
        }

        static audio_engine engine(const audio_node_sptr &node)
        {
            return node->engine();
        }

        static void update_kernel(const audio_node_sptr &node)
        {
            node->update_kernel();
        }

        static kernel_sptr kernel(const audio_node_sptr &node)
        {
            return node->_kernel();
        }

        static void update_connections(const audio_node_sptr &node)
        {
            node->update_connections();
        }
    };
}
