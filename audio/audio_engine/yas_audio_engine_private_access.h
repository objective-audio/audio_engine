//
//  yas_audio_engine_private_access.h
//

#pragma once

#if YAS_TEST

namespace yas {
namespace audio {
    class engine::private_access {
       public:
        static std::unordered_set<node> &nodes(engine const &engine) {
            return engine.impl_ptr<impl>()->nodes();
        }

        static audio::connection_set &connections(engine const &engine) {
            return engine.impl_ptr<impl>()->connections();
        }
    };
}
}

#endif
