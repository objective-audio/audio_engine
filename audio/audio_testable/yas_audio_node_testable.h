//
//  yas_audio_node_testable.h
//

#pragma once

#if YAS_TEST

#include "yas_protocol.h"

namespace yas {
namespace audio {
    struct testable_node : protocol {
        struct impl : protocol::impl {};

        static node create() {
            return audio::node(std::make_shared<audio::node::impl>());
        }

        static audio::node::kernel kernel(audio::node const &node) {
            return node.impl_ptr<audio::node::impl>()->kernel_cast();
        }
    };
}
}

#endif
