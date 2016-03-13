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
        /*
                static audio::connection input_connection(node const &node, UInt32 const bus_idx) {
                    return node.manageable_node().input_connection(bus_idx);
                }

                static audio::connection output_connection(node const &node, UInt32 const bus_idx) {
                    return node.manageable_node().output_connection(bus_idx);
                }

                static audio::connection_wmap const &input_connections(node const &node) {
                    return node.manageable_node().input_connections();
                }

                static audio::connection_wmap const &output_connections(node const &node) {
                    return node.manageable_node().output_connections();
                }

                static void add_connection(node &node, audio::connection const &connection) {
                    node.manageable_node().add_connection(connection);
                }

                static void remove_connection(node &node, audio::connection const &connection) {
                    node.manageable_node().remove_connection(connection);
                }

                static void set_engine(node &node, audio::engine const &engine) {
                    node.manageable_node().set_engine(engine);
                }

                static void update_kernel(node &node) {
                    node.manageable_node().update_kernel();
                }
        */
        static std::shared_ptr<kernel> kernel(node const &node) {
            return node.impl_ptr<impl>()->kernel_cast();
        }
    };
}
}

#endif
