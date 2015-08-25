//
//  yas_audio_connection.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_format.h"
#include <memory>

namespace yas
{
    class audio_connection
    {
       public:
        ~audio_connection();

        UInt32 source_bus() const;
        UInt32 destination_bus() const;
        audio_node_sptr source_node() const;
        audio_node_sptr destination_node() const;
        audio_format_sptr &format() const;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        static audio_connection_sptr _create(const audio_node_sptr &source_node, const UInt32 source_bus,
                                            const audio_node_sptr &destination_node, const UInt32 destination_bus,
                                            const audio_format_sptr &format);

        audio_connection(const audio_node_sptr &source_node, const UInt32 source_bus,
                         const audio_node_sptr &destination_node, const UInt32 destination_bus,
                         const audio_format_sptr &format);

        audio_connection(const audio_connection &) = delete;
        audio_connection(audio_connection &&) = delete;
        audio_connection &operator=(const audio_connection &) = delete;
        audio_connection &operator=(audio_connection &&) = delete;

        void _remove_nodes();
        void _remove_source_node();
        void _remove_destination_node();

       public:
        class private_access;
        friend private_access;
    };
}

#include "yas_audio_connection_private_access.h"
