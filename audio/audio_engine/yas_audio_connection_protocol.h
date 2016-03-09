//
//  yas_audio_connection_protocol.h
//

#pragma once

#include <MacTypes.h>
#include <unordered_set>
#include "yas_base.h"

namespace yas {
namespace audio {
    class connection;

    using connection_set = std::unordered_set<connection>;
    using connection_smap = std::map<UInt32, connection>;
    using connection_wmap = std::map<UInt32, weak<connection>>;

    class manageable_connection {
       public:
        virtual ~manageable_connection() = default;

        virtual void _remove_nodes() = 0;
        virtual void _remove_source_node() = 0;
        virtual void _remove_destination_node() = 0;
    };
}
}
