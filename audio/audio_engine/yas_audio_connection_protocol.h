//
//  yas_audio_connection_protocol.h
//

#pragma once

#include <MacTypes.h>
#include <unordered_set>
#include "yas_base.h"
#include "yas_protocol.h"

namespace yas {
namespace audio {
    class connection;

    using connection_set = std::unordered_set<connection>;
    using connection_smap = std::map<UInt32, connection>;
    using connection_wmap = std::map<UInt32, weak<connection>>;

    struct node_removable : protocol {
        struct impl : protocol::impl {
            virtual void remove_nodes() = 0;
            virtual void remove_source_node() = 0;
            virtual void remove_destination_node() = 0;
        };

        explicit node_removable(std::shared_ptr<impl> impl) : protocol(impl) {
        }

        void remove_nodes() {
            impl_ptr<impl>()->remove_nodes();
        }

        void remove_source_node() {
            impl_ptr<impl>()->remove_source_node();
        }

        void remove_destination_node() {
            impl_ptr<impl>()->remove_destination_node();
        }
    };
}
}
