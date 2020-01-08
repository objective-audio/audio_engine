//
//  yas_audio_graph_connection_protocol.h
//

#pragma once

#include <map>
#include <unordered_set>
#include "yas_audio_ptr.h"

namespace yas::audio {
using graph_connection_set = std::unordered_set<graph_connection_ptr>;
using graph_connection_smap = std::map<uint32_t, graph_connection_ptr>;
using graph_connection_wmap = std::map<uint32_t, std::weak_ptr<graph_connection>>;

struct graph_node_removable {
    virtual ~graph_node_removable() = default;

    virtual void remove_nodes() = 0;
    virtual void remove_source_node() = 0;
    virtual void remove_destination_node() = 0;

    static graph_node_removable_ptr cast(graph_node_removable_ptr const &removable) {
        return removable;
    }
};
}  // namespace yas::audio
