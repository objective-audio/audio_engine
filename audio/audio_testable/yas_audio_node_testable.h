//
//  yas_audio_node_testable.h
//

#pragma once

#if YAS_TEST

#include "yas_audio_engine.h"

namespace yas {
namespace audio {
    struct node::testable {
        static node create() {
            return node(std::make_shared<node::impl>());
        }

        static audio::node::kernel kernel(node const &node) {
            return node.impl_ptr<impl>()->kernel_cast();
        }
    };
}
}

#endif
