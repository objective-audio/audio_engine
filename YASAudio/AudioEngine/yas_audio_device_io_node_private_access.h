//
//  yas_audio_device_io_node_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

namespace yas
{
    class audio_graph;

    using audio_graph_ptr = std::shared_ptr<audio_graph>;

    class audio_device_io_node::private_access
    {
       public:
        static void add_audio_device_io_to_graph(audio_device_io_node *node, const audio_graph_ptr &graph)
        {
            node->_add_audio_device_io_to_graph(graph);
        }

        static void remove_audio_device_io_from_graph(audio_device_io_node *node)
        {
            node->_remove_audio_device_io_from_graph();
        }
    };
}

#endif