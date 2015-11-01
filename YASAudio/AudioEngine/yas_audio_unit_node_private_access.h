//
//  yas_audio_unit_node_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#if YAS_TEST

namespace yas
{
    class audio_unit_node::private_access
    {
       public:
        template <typename T>
        static void reload_audio_unit(T &node)
        {
            node._impl_ptr()->reload_audio_unit();
        }

        template <typename T>
        static void prepare_parameters(T &node)
        {
            node._impl_ptr()->prepare_parameters();
        }
    };
}

#endif
