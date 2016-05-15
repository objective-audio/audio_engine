//
//  yas_audio_node_testable.h
//

#pragma once

#if YAS_TEST

namespace yas {
namespace audio {
    struct testable_node {
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
