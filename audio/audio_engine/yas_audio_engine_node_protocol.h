//
//  yas_audio_engine_node_protocol.h
//

#pragma once

#include <optional>
#include "yas_audio_engine_connection_protocol.h"
#include "yas_audio_engine_ptr.h"

namespace yas::audio {
using graph_editing_f = std::function<void(audio::graph &)>;
}  // namespace yas::audio

namespace yas::audio::engine {
struct node_args {
    uint32_t input_bus_count = 0;
    uint32_t output_bus_count = 0;
    std::optional<uint32_t> override_output_bus_idx;
    bool input_renderable = false;
};

struct connectable_node {
    virtual ~connectable_node() = default;

    virtual void add_connection(audio::engine::connection_ptr const &) = 0;
    virtual void remove_input_connection(uint32_t const dst_bus) = 0;
    virtual void remove_output_connection(uint32_t const src_bus) = 0;

    static connectable_node_ptr cast(connectable_node_ptr const &node) {
        return node;
    }
};

struct manageable_node {
    virtual audio::engine::connection_ptr input_connection(uint32_t const bus_idx) const = 0;
    virtual audio::engine::connection_ptr output_connection(uint32_t const bus_idx) const = 0;
    virtual audio::engine::connection_wmap const &input_connections() const = 0;
    virtual audio::engine::connection_wmap const &output_connections() const = 0;
    virtual void set_manager(audio::engine::manager_wptr const &) = 0;
    virtual audio::engine::manager_ptr manager() const = 0;
    virtual void update_kernel() = 0;
    virtual void update_connections() = 0;
    virtual void set_add_to_graph_handler(graph_editing_f &&) = 0;
    virtual void set_remove_from_graph_handler(graph_editing_f &&) = 0;
    virtual graph_editing_f const &add_to_graph_handler() const = 0;
    virtual graph_editing_f const &remove_from_graph_handler() const = 0;

    static manageable_node_ptr cast(manageable_node_ptr const &node) {
        return node;
    }
};
}  // namespace yas::audio::engine
