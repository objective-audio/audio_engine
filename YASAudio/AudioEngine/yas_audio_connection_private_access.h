//
//  yas_audio_connection_private_access.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

namespace yas
{
    class audio_connection::private_access
    {
       public:
        static audio_connection_sptr create(const audio_node_sptr &source_node, const UInt32 source_bus,
                                            const audio_node_sptr &destination_node, const UInt32 destination_bus,
                                            const audio_format &format)
        {
            return audio_connection::_create(source_node, source_bus, destination_node, destination_bus, format);
        }

        static void remove_nodes(const audio_connection_sptr &connection)
        {
            connection->_remove_nodes();
        }

        static void remove_source_node(const audio_connection_sptr &connection)
        {
            connection->_remove_source_node();
        }

        static void remove_destination_node(const audio_connection_sptr &connection)
        {
            connection->_remove_destination_node();
        }
    };
}
