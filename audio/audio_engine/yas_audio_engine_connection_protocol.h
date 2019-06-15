//
//  yas_audio_engine_connection_protocol.h
//

#pragma once

#include <cpp_utils/yas_base.h>
#include <cpp_utils/yas_protocol.h>
#include <unordered_set>

namespace yas::audio::engine {
class connection;

using connection_set = std::unordered_set<connection>;
using connection_smap = std::map<uint32_t, connection>;
using connection_wmap = std::map<uint32_t, base::weak<connection>>;

struct node_removable : protocol {
    struct impl : protocol::impl {
        virtual void remove_nodes() = 0;
        virtual void remove_source_node() = 0;
        virtual void remove_destination_node() = 0;
    };

    explicit node_removable(std::shared_ptr<impl> impl);
    node_removable(std::nullptr_t);

    void remove_nodes();
    void remove_source_node();
    void remove_destination_node();
};
}  // namespace yas::audio::engine
