//
//  yas_audio_connection.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_format.h"
#include "yas_base.h"
#include <memory>
#include <unordered_map>

namespace yas
{
    class audio_node;

    class audio_connection : public base
    {
       public:
        audio_connection(std::nullptr_t);
        ~audio_connection();

        audio_connection(const audio_connection &) = default;
        audio_connection(audio_connection &&) = default;
        audio_connection &operator=(const audio_connection &) = default;
        audio_connection &operator=(audio_connection &&) = default;

        UInt32 source_bus() const;
        UInt32 destination_bus() const;
        audio_node source_node() const;
        audio_node destination_node() const;
        audio_format &format() const;

       private:
        using super_class = base;

        audio_connection(audio_node &source_node, const UInt32 source_bus, audio_node &destination_node,
                         const UInt32 destination_bus, const audio_format &format);
        audio_connection(const std::shared_ptr<impl> &);

        void _remove_nodes();
        void _remove_source_node();
        void _remove_destination_node();

        class impl;
        std::shared_ptr<impl> _impl_ptr() const;

       public:
        class private_access;
        friend private_access;
    };

    using audio_connection_map = std::unordered_map<uintptr_t, audio_connection>;
    using audio_connection_smap = std::map<UInt32, audio_connection>;
    using audio_connection_wmap = std::map<UInt32, base_weak<audio_connection>>;
    using audio_connection_wmap_sptr = std::shared_ptr<audio_connection_wmap>;
}

#include "yas_audio_connection_private_access.h"
