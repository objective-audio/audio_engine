//
//  yas_audio_engine_connection_protocol.h
//

#pragma once

#include <cpp_utils/yas_protocol.h>
#include <map>
#include <unordered_set>
#include "yas_audio_engine_ptr.h"

namespace yas::audio::engine {
using connection_set = std::unordered_set<connection_ptr>;
using connection_smap = std::map<uint32_t, connection_ptr>;
using connection_wmap = std::map<uint32_t, std::weak_ptr<connection>>;

struct node_removable {
    virtual ~node_removable() = default;

    virtual void remove_nodes() = 0;
    virtual void remove_source_node() = 0;
    virtual void remove_destination_node() = 0;
};

using node_removable_ptr = std::shared_ptr<node_removable>;
}  // namespace yas::audio::engine
