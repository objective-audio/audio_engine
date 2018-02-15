//
//  yas_audio_engine_connection.h
//

#pragma once

#include "yas_audio_engine_connection_protocol.h"
#include "yas_audio_format.h"
#include "yas_base.h"

namespace yas::audio::engine {
class node;

class connection : public base {
    class impl;

   public:
    connection(std::nullptr_t);

    virtual ~connection();

    uint32_t source_bus() const;
    uint32_t destination_bus() const;
    audio::engine::node source_node() const;
    audio::engine::node destination_node() const;
    audio::format const &format() const;

    audio::engine::node_removable &node_removable();

   protected:
    connection(audio::engine::node &source_node, uint32_t const source_bus_idx, audio::engine::node &destination_node,
               uint32_t const destination_bus_idx, audio::format const &format);

   private:
    audio::engine::node_removable _node_removable = nullptr;
};
}

template <>
struct std::hash<yas::audio::engine::connection> {
    std::size_t operator()(yas::audio::engine::connection const &key) const {
        return std::hash<uintptr_t>()(key.identifier());
    }
};
