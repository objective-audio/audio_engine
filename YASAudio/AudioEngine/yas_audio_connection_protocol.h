//
//  yas_audio_connection_protocol.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_base.h"
#include <unordered_map>
#include <MacTypes.h>

namespace yas
{
    class audio_connection;
    class audio_node;
    class audio_format;

    using audio_connection_map = std::unordered_map<uintptr_t, audio_connection>;
    using audio_connection_smap = std::map<UInt32, audio_connection>;
    using audio_connection_wmap = std::map<UInt32, base_weak<audio_connection>>;
    using audio_connection_wmap_sptr = std::shared_ptr<audio_connection_wmap>;

    class audio_connection_from_engine
    {
       public:
        virtual ~audio_connection_from_engine() = default;

        virtual void _remove_nodes() = 0;
        virtual void _remove_source_node() = 0;
        virtual void _remove_destination_node() = 0;
    };
}
