//
//  yas_audio_engine_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#if YAS_TEST

namespace yas
{
    class audio_engine::private_access
    {
       public:
        static std::unordered_set<audio_node> &nodes(const audio_engine &engine)
        {
            return engine.impl_ptr<impl>()->nodes();
        }

        static audio_connection_map &connections(const audio_engine &engine)
        {
            return engine.impl_ptr<impl>()->connections();
        }
    };
}

#endif
