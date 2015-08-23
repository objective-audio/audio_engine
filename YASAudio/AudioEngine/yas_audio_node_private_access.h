//
//  yas_audio_node_test_utils.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas
{
    class audio_node::private_access
    {
       public:
        static audio_node_ptr create()
        {
            return audio_node_ptr(new audio_node());
        }

        static audio_connection_ptr input_connection(const audio_node_ptr &node, const uint32_t bus_idx)
        {
            return node->input_connection(bus_idx);
        }

        static audio_connection_ptr output_connection(const audio_node_ptr &node, const uint32_t bus_idx)
        {
            return node->output_connection(bus_idx);
        }

        static const audio_connection_weak_map &input_connections(const audio_node_ptr &node)
        {
            return node->input_connections();
        }

        static const audio_connection_weak_map &output_connections(const audio_node_ptr &node)
        {
            return node->output_connections();
        }

        static void add_connection(const audio_node_ptr &node, const audio_connection_ptr &connection)
        {
            node->add_connection(connection);
        }

        static void remove_connection(const audio_node_ptr &node, const audio_connection &connection)
        {
            node->remove_connection(connection);
        }

        static void set_engine(const audio_node_ptr &node, const audio_engine_ptr &engine)
        {
            node->set_engine(engine);
        }

        static audio_engine_ptr engine(const audio_node_ptr &node)
        {
            return node->engine();
        }

        static void update_node_core(const audio_node_ptr &node)
        {
            node->update_node_core();
        }

        static audio_node_core_ptr node_core(const audio_node_ptr &node)
        {
            return node->node_core();
        }
    };
}
