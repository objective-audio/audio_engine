//
//  yas_audio_engine_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

namespace yas
{
    class audio_engine::private_access
    {
       public:
        static std::unordered_map<uintptr_t, audio_node> &nodes(const audio_engine &engine)
        {
            return engine._nodes();
        }

        static audio_connection_map &connections(const audio_engine &engine)
        {
            return engine._connections();
        }
    };
}
