//
//  yas_audio_engine_connection.h
//

#pragma once

#include "yas_audio_engine_connection_protocol.h"
#include "yas_audio_engine_ptr.h"
#include "yas_audio_format.h"

namespace yas::audio::engine {
struct connection : node_removable {
    virtual ~connection();

    uint32_t const source_bus;
    uint32_t const destination_bus;
    audio::engine::node_ptr source_node() const;
    audio::engine::node_ptr destination_node() const;
    audio::format const format;

    node_removable_ptr removable();

   private:
    mutable std::recursive_mutex _mutex;
    std::weak_ptr<node> _source_node;
    std::weak_ptr<node> _destination_node;
    std::weak_ptr<connection> _weak_connection;

    connection(audio::engine::node_ptr const &source_node, uint32_t const source_bus_idx,
               audio::engine::node_ptr const &destination_node, uint32_t const destination_bus_idx,
               audio::format const &format);

    connection(connection const &) = delete;
    connection(connection &&) = delete;
    connection &operator=(connection const &) = delete;
    connection &operator=(connection &&) = delete;

    void remove_nodes() override;
    void remove_source_node() override;
    void remove_destination_node() override;

    void _prepare(connection_ptr const &);

   public:
    static connection_ptr make_shared(audio::engine::node_ptr const &src_node, uint32_t const src_bus,
                                      audio::engine::node_ptr const &dst_node, uint32_t const dst_bus,
                                      audio::format const &format);
};
}  // namespace yas::audio::engine
