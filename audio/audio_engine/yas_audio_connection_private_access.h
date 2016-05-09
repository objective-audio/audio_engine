//
//  yas_audio_connection_private_access.h
//

#pragma once

#if YAS_TEST

namespace yas {
namespace audio {
    class connection::private_access {
       public:
        static connection create(node &source_node, uint32_t const source_bus, node &destination_node,
                                 uint32_t const destination_bus, audio::format const &format) {
            return connection(source_node, source_bus, destination_node, destination_bus, format);
        }
    };
}
}

#endif
