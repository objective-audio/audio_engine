//
//  yas_audio_connection.h
//

#pragma once

#include "yas_audio_connection_protocol.h"
#include "yas_audio_format.h"
#include "yas_base.h"

namespace yas {
namespace audio {
    class node;
    class testable_connection;

    class connection : public base {
        class impl;

       public:
        connection(std::nullptr_t);
        ~connection();

        uint32_t source_bus() const;
        uint32_t destination_bus() const;
        audio::node source_node() const;
        audio::node destination_node() const;
        audio::format const &format() const;

        audio::node_removable node_removable();

       protected:
        connection(audio::node &source_node, uint32_t const source_bus_idx, audio::node &destination_node,
                   uint32_t const destination_bus_idx, audio::format const &format);
    };
}
}

template <>
struct std::hash<yas::audio::connection> {
    std::size_t operator()(yas::audio::connection const &key) const {
        return std::hash<uintptr_t>()(key.identifier());
    }
};
