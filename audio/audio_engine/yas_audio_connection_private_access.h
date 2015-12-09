//
//  yas_audio_connection_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#if YAS_TEST

namespace yas {
namespace audio {
    class connection::private_access {
       public:
        static connection create(node &source_node, const UInt32 source_bus, node &destination_node,
                                 const UInt32 destination_bus, const audio::format &format) {
            return connection(source_node, source_bus, destination_node, destination_bus, format);
        }

        static void remove_nodes(connection &connection) {
            connection._remove_nodes();
        }

        static void remove_source_node(connection &connection) {
            connection._remove_source_node();
        }

        static void remove_destination_node(connection &connection) {
            connection._remove_destination_node();
        }
    };
}
}

#endif
