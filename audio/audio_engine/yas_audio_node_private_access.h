//
//  yas_audio_node_private_access.h
//

#pragma once

#if YAS_TEST

#include "yas_audio_engine.h"

namespace yas {
namespace audio {
    class node::private_access {
       public:
        static node create() {
            return node(std::make_shared<node::impl>());
        }

        static std::shared_ptr<kernel> kernel(node const &node) {
            return node.impl_ptr<impl>()->kernel_cast();
        }
    };
}
}

#endif
