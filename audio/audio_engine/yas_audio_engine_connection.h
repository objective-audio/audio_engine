//
//  yas_audio_engine_connection.h
//

#pragma once

#include <cpp_utils/yas_base.h>
#include "yas_audio_engine_connection_protocol.h"
#include "yas_audio_format.h"

namespace yas::audio::engine {
class node;

struct connection : node_removable, std::enable_shared_from_this<connection> {
    virtual ~connection();

    uint32_t const source_bus;
    uint32_t const destination_bus;
    std::shared_ptr<audio::engine::node> source_node() const;
    std::shared_ptr<audio::engine::node> destination_node() const;
    audio::format const format;

    void remove_nodes() override;
    void remove_source_node() override;
    void remove_destination_node() override;

   protected:
    connection(audio::engine::node &source_node, uint32_t const source_bus_idx, audio::engine::node &destination_node,
               uint32_t const destination_bus_idx, audio::format const &format);

   private:
    mutable std::recursive_mutex _mutex;
    std::weak_ptr<node> _source_node;
    std::weak_ptr<node> _destination_node;

    connection(connection const &) = delete;
    connection(connection &&) = delete;
    connection &operator=(connection const &) = delete;
    connection &operator=(connection &&) = delete;

    void _remove_connection_from_nodes(connection const &);
};

std::shared_ptr<connection> make_connection(audio::engine::node &src_node, uint32_t const src_bus,
                                            audio::engine::node &dst_node, uint32_t const dst_bus,
                                            audio::format const &format);
}  // namespace yas::audio::engine
