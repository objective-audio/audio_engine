//
//  yas_audio_connection_testable.h
//

#pragma once

#if YAS_TEST

#include "yas_protocol.h"

namespace yas {
namespace audio {
    struct testable_connection : protocol {
        struct impl : protocol::impl {};

        static audio::connection create(node &source_node, uint32_t const source_bus, node &destination_node,
                                        uint32_t const destination_bus, audio::format const &format) {
            return audio::connection{source_node, source_bus, destination_node, destination_bus, format};
        }
    };
}
}

#endif
