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
    class testable_connection;

    class connection : public base {
        class impl;

       public:
        connection(std::nullptr_t);
        ~connection();

        uint32_t source_bus() const;
        uint32_t destination_bus() const;
        node source_node() const;
        node destination_node() const;
        audio::format const &format() const;

        node_removable node_removable();

       protected:
        connection(node &source_node, uint32_t const source_bus, node &destination_node, uint32_t const destination_bus,
                   audio::format const &format);
#if YAS_TEST
       public:
        friend testable_connection;
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
#include "yas_audio_connection_testable.h"
#endif
