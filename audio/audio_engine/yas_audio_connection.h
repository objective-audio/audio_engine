//
//  yas_audio_connection.h
//

#pragma once

#include <memory>
#include "yas_audio_connection_protocol.h"
#include "yas_audio_format.h"
#include "yas_base.h"

namespace yas {
namespace audio {
    class node;

    class connection : public base, public manageable_connection {
        using super_class = base;
        class impl;

       public:
        connection(std::nullptr_t);
        ~connection();

        connection(connection const &) = default;
        connection(connection &&) = default;
        connection &operator=(connection const &) = default;
        connection &operator=(connection &&) = default;

        UInt32 source_bus() const;
        UInt32 destination_bus() const;
        node source_node() const;
        node destination_node() const;
        audio::format const &format() const;

       protected:
        connection(node &source_node, UInt32 const source_bus, node &destination_node, UInt32 const destination_bus,
                   audio::format const &format);

        void _remove_nodes() override;
        void _remove_source_node() override;
        void _remove_destination_node() override;
#if YAS_TEST
       public:
        class private_access;
        friend private_access;
#endif
    };
}
}

template <>
struct std::hash<yas::audio::connection> {
    std::size_t operator()(yas::audio::connection const &key) const {
        return std::hash<uintptr_t>()(key.identifier());
    }
};

#if YAS_TEST
#include "yas_audio_connection_private_access.h"
#endif
