//
//  yas_audio_unit_node_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas
{
    class audio_unit_node::private_access
    {
       public:
        template <typename T>
        static void reload_audio_unit(T &node)
        {
            node->_reload_audio_unit();
        }

        template <typename T>
        static void prepare_parameters(T &node)
        {
            node->prepare_parameters();
        }

        template <typename T>
        static void add_audio_unit_to_graph(T &node, const audio_graph_ptr &graph)
        {
            node->_add_audio_unit_to_graph(graph);
        }

        template <typename T>
        static void remove_audio_unit_from_graph(T &node)
        {
            node->_remove_audio_unit_from_graph();
        }
    };
}
