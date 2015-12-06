//
//  yas_audio_connection_protocol.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_base.h"
#include <unordered_set>
#include <MacTypes.h>

namespace yas {
namespace audio {
    class connection;

    using connection_set = std::unordered_set<connection>;
    using connection_smap = std::map<UInt32, connection>;
    using connection_wmap = std::map<UInt32, weak<connection>>;

    class connection_from_engine {
       public:
        virtual ~connection_from_engine() = default;

        virtual void _remove_nodes() = 0;
        virtual void _remove_source_node() = 0;
        virtual void _remove_destination_node() = 0;
    };
}
}
