//
//  yas_audio_graph_connection_protocol.h
//

#pragma once

#include <audio-engine/common/yas_audio_ptr.h>

#include <map>
#include <unordered_set>

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

struct renderable_graph_connection {
    virtual uint32_t source_bus() const = 0;
    virtual graph_node_ptr source_node() const = 0;
    virtual graph_node_ptr destination_node() const = 0;
    virtual audio::format const &format() const = 0;
};
}  // namespace yas::audio
