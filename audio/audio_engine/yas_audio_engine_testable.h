//
//  yas_audio_engine_testable.h
//

#pragma once

#if YAS_TEST

namespace yas {
namespace audio {
    struct engine::testable {
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
