//
//  yas_audio_engine_test_utils.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

namespace yas
{
    class audio_engine::private_access
    {
       public:
        static std::set<audio_node_ptr> &nodes(const audio_engine_ptr &engine)
        {
            return engine->nodes();
        }

        static std::set<audio_connection_ptr> &connections(const audio_engine_ptr &engine)
        {
            return engine->connections();
        }
    };
}
