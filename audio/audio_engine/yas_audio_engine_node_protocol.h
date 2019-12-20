//
//  yas_audio_engine_node_protocol.h
//

#pragma once

#include <optional>
#include "yas_audio_engine_connection_protocol.h"
#include "yas_audio_engine_ptr.h"

namespace yas::audio::engine {
using node_setup_f = std::function<void(void)>;

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
    virtual void set_setup_handler(node_setup_f &&) = 0;
    virtual void set_teardown_handler(node_setup_f &&) = 0;
    virtual node_setup_f const &setup_handler() const = 0;
    virtual node_setup_f const &teardown_handler() const = 0;

    static manageable_node_ptr cast(manageable_node_ptr const &node) {
        return node;
    }
};
}  // namespace yas::audio::engine
