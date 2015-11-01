//
//  yas_audio_device_io_node_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
#if YAS_TEST

namespace yas
{
    class audio_graph;

    class audio_device_io_node::private_access
    {
       public:
        static void add_audio_device_io_to_graph(audio_device_io_node node, audio_graph &graph)
        {
            node._impl_ptr()->add_device_io_to_graph(graph);
        }

        static void remove_audio_device_io_from_graph(audio_device_io_node node)
        {
            node._impl_ptr()->remove_device_io_from_graph();
        }
    };
}

#endif
#endif
