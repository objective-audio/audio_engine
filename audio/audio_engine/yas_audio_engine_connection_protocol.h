//
//  yas_audio_engine_connection_protocol.h
//

#pragma once

#include <cpp_utils/yas_protocol.h>
#include <map>
#include <unordered_set>

namespace yas::audio::engine {
class connection;

using connection_set = std::unordered_set<std::shared_ptr<connection>>;
using connection_smap = std::map<uint32_t, std::shared_ptr<connection>>;
using connection_wmap = std::map<uint32_t, std::weak_ptr<connection>>;

struct node_removable {
    virtual ~node_removable() = default;

    virtual void remove_nodes() = 0;
    virtual void remove_source_node() = 0;
    virtual void remove_destination_node() = 0;
};
}  // namespace yas::audio::engine
