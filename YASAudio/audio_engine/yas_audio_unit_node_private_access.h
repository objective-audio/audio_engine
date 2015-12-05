//
//  yas_audio_unit_node_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#if YAS_TEST

namespace yas
{
    namespace audio
    {
        class unit_node::private_access
        {
           public:
            static void reload_audio_unit(unit_node &node)
            {
                node.impl_ptr<impl>()->reload_audio_unit();
            }

            static void prepare_parameters(unit_node &node)
            {
                node.impl_ptr<impl>()->prepare_parameters();
            }
        };
    }
}

#endif
