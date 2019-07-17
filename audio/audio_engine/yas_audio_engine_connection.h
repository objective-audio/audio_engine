//
//  yas_audio_engine_connection.h
//

#pragma once

#include <cpp_utils/yas_base.h>
#include "yas_audio_engine_connection_protocol.h"
#include "yas_audio_format.h"

namespace yas::audio::engine {
class node;

struct connection : base, node_removable, std::enable_shared_from_this<connection> {
    class impl;

    virtual ~connection();

    uint32_t source_bus() const;
    uint32_t destination_bus() const;
    std::shared_ptr<audio::engine::node> source_node() const;
    std::shared_ptr<audio::engine::node> destination_node() const;
    audio::format const &format() const;

    void remove_nodes() override;
    void remove_source_node() override;
    void remove_destination_node() override;

   protected:
    connection(audio::engine::node &source_node, uint32_t const source_bus_idx, audio::engine::node &destination_node,
               uint32_t const destination_bus_idx, audio::format const &format);

   private:
    connection(connection const &) = delete;
    connection(connection &&) = delete;
    connection &operator=(connection const &) = delete;
    connection &operator=(connection &&) = delete;
};

std::shared_ptr<connection> make_connection(audio::engine::node &src_node, uint32_t const src_bus,
                                            audio::engine::node &dst_node, uint32_t const dst_bus,
                                            audio::format const &format);
}  // namespace yas::audio::engine

template <>
struct std::hash<yas::audio::engine::connection> {
    std::size_t operator()(yas::audio::engine::connection const &key) const {
        return std::hash<uintptr_t>()(key.identifier());
    }
};
