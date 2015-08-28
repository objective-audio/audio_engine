//
//  yas_audio_node_test_utils.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas
{
    class audio_node_core::private_access
    {
       public:
        static void set_input_connections(const audio_node_core_sptr &node, const audio_connection_wmap &connections)
        {
            node->set_input_connections(connections);
        }

        static void set_output_connections(const audio_node_core_sptr &node, const audio_connection_wmap &connections)
        {
            node->set_output_connections(connections);
        }
    };

    class audio_node::private_access
    {
       public:
        static audio_node_sptr create()
        {
            return audio_node_sptr(new audio_node());
        }

        static audio_connection_sptr input_connection(const audio_node_sptr &node, const uint32_t bus_idx)
        {
            return node->input_connection(bus_idx);
        }

        static audio_connection_sptr output_connection(const audio_node_sptr &node, const uint32_t bus_idx)
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

        static void add_connection(const audio_node_sptr &node, const audio_connection_sptr &connection)
        {
            node->_add_connection(connection);
        }

        static void remove_connection(const audio_node_sptr &node, const audio_connection &connection)
        {
            node->_remove_connection(connection);
        }

        static void set_engine(const audio_node_sptr &node, const audio_engine_sptr &engine)
        {
            node->_set_engine(engine);
        }

        static audio_engine_sptr engine(const audio_node_sptr &node)
        {
            return node->engine();
        }

        static void update_node_core(const audio_node_sptr &node)
        {
            node->update_node_core();
        }

        static audio_node_core_sptr node_core(const audio_node_sptr &node)
        {
            return node->node_core();
        }

        static void update_connections(const audio_node_sptr &node)
        {
            node->update_connections();
        }
    };
}
