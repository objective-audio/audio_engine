//
//  yas_audio_engine_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#if YAS_TEST

namespace yas
{
    namespace audio
    {
        class engine::private_access
        {
           public:
            static std::unordered_set<audio_node> &nodes(const engine &engine)
            {
                return engine.impl_ptr<impl>()->nodes();
            }

            static audio::connection_set &connections(const engine &engine)
            {
                return engine.impl_ptr<impl>()->connections();
            }
        };
    }
}

#endif
