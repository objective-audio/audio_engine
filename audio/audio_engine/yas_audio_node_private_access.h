//
//  yas_audio_node_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
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

        static audio::connection input_connection(node const &node, UInt32 const bus_idx) {
            return node._input_connection(bus_idx);
        }

        static audio::connection output_connection(node const &node, UInt32 const bus_idx) {
            return node._output_connection(bus_idx);
        }

        static audio::connection_wmap const &input_connections(node const &node) {
            return node._input_connections();
        }

        static audio::connection_wmap const &output_connections(node const &node) {
            return node._output_connections();
        }

        static void add_connection(node &node, audio::connection const &connection) {
            node._add_connection(connection);
        }

        static void remove_connection(node &node, audio::connection const &connection) {
            node.impl_ptr<impl>()->remove_connection(connection);
        }

        static void set_engine(node &node, audio::engine const &engine) {
            node._set_engine(engine);
        }

        static void update_kernel(node &node) {
            node.impl_ptr<impl>()->update_kernel();
        }

        static std::shared_ptr<kernel> kernel(node const &node) {
            return node.impl_ptr<impl>()->kernel_cast();
        }
    };
}
}

#endif
