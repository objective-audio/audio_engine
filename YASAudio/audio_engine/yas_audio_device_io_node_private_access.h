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
    };
}

#endif
#endif
