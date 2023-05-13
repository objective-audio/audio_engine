//
//  yas_audio_graph_node_protocol.h
//

#pragma once

#include <audio/yas_audio_graph_connection_protocol.h>
#include <audio/yas_audio_ptr.h>
#include <audio/yas_audio_rendering_types.h>

#include <observing/yas_observing_umbrella.hpp>
#include <optional>

namespace yas::audio {
using graph_node_set = std::unordered_set<graph_node_ptr>;
using graph_node_f = std::function<void(void)>;

struct graph_node_args {
    uint32_t input_bus_count = 0;
    uint32_t output_bus_count = 0;
    std::optional<uint32_t> override_output_bus_idx;
    bool input_renderable = false;
};

struct connectable_graph_node {
    virtual ~connectable_graph_node() = default;

    virtual void add_connection(graph_connection_ptr const &) = 0;
    virtual void remove_input_connection(uint32_t const dst_bus) = 0;
    virtual void remove_output_connection(uint32_t const src_bus) = 0;

    static connectable_graph_node_ptr cast(connectable_graph_node_ptr const &node) {
        return node;
    }
};

struct manageable_graph_node {
    virtual graph_connection_ptr input_connection(uint32_t const bus_idx) const = 0;
    virtual graph_connection_ptr output_connection(uint32_t const bus_idx) const = 0;
    virtual graph_connection_wmap const &input_connections() const = 0;
    virtual graph_connection_wmap const &output_connections() const = 0;
    virtual void set_graph(graph_wptr const &) = 0;
    virtual graph_ptr graph() const = 0;
    virtual void update_rendering() = 0;
    virtual void set_setup_handler(graph_node_f &&) = 0;
    virtual void set_teardown_handler(graph_node_f &&) = 0;
    virtual void set_prepare_rendering_handler(graph_node_f &&) = 0;
    virtual void set_update_rendering_handler(graph_node_f &&) = 0;
    virtual void set_will_reset_handler(graph_node_f &&) = 0;
    virtual graph_node_f const &setup_handler() const = 0;
    virtual graph_node_f const &teardown_handler() const = 0;

    static manageable_graph_node_ptr cast(manageable_graph_node_ptr const &node) {
        return node;
    }
};

struct renderable_graph_node {
    virtual void prepare_rendering() = 0;
    virtual void update_rendering() = 0;
    virtual graph_connection_wmap const &input_connections() const = 0;
    virtual graph_connection_wmap const &output_connections() const = 0;
    virtual bool is_input_renderable() const = 0;
    virtual node_render_f const render_handler() const = 0;

    static renderable_graph_node_ptr cast(renderable_graph_node_ptr const &node) {
        return node;
    }
};
}  // namespace yas::audio
