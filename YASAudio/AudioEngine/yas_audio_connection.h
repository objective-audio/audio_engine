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
    class audio_connection;
    class audio_node;
    class audio_unit_node;
    class audio_engine;

    using audio_connection_ptr = std::shared_ptr<audio_connection>;
    using audio_connection_weak_ptr = std::weak_ptr<audio_connection>;
    using audio_node_ptr = std::shared_ptr<audio_node>;

    class audio_connection
    {
       public:
        ~audio_connection();

        UInt32 source_bus() const;
        UInt32 destination_bus() const;
        audio_node_ptr source_node() const;
        audio_node_ptr destination_node() const;
        audio_format_ptr &format() const;

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        static audio_connection_ptr create(const audio_node_ptr &source_node, const UInt32 source_bus,
                                           const audio_node_ptr &destination_node, const UInt32 destination_bus,
                                           const audio_format_ptr &format);

        audio_connection(const audio_node_ptr &source_node, const UInt32 source_bus,
                         const audio_node_ptr &destination_node, const UInt32 destination_bus,
                         const audio_format_ptr &format);

        audio_connection(const audio_connection &) = delete;
        audio_connection(audio_connection &&) = delete;
        audio_connection &operator=(const audio_connection &) = delete;
        audio_connection &operator=(audio_connection &&) = delete;

        void remove_nodes();
        void remove_source_node();
        void remove_destination_node();

       public:
        class private_access;
        friend private_access;
    };
}

#include "yas_audio_connection_private_access.h"
