//
//  yas_audio_graph.h
//

#pragma once

#include <chaining/yas_chaining_umbrella.h>

#include <ostream>

#include "yas_audio_graph_connection.h"
#include "yas_audio_ptr.h"
#include "yas_audio_types.h"

namespace yas {
template <typename T, typename U>
class result;
}  // namespace yas

namespace yas::audio {
struct graph final {
    enum class start_error_t {
        already_running,
        prepare_failure,
        connection_not_found,
    };

    using start_result_t = result<std::nullptr_t, start_error_t>;

    virtual ~graph();

    graph_connection_ptr connect(graph_node_ptr const &source_node, graph_node_ptr const &destination_node,
                                 audio::format const &format);
    graph_connection_ptr connect(graph_node_ptr const &source_node, graph_node_ptr const &destination_node,
                                 uint32_t const source_bus_idx, uint32_t const destination_bus_idx,
                                 audio::format const &format);

    void disconnect(graph_connection_ptr const &);
    void disconnect(graph_node_ptr const &);
    void disconnect_input(graph_node_ptr const &);
    void disconnect_input(graph_node_ptr const &, uint32_t const bus_idx);
    void disconnect_output(graph_node_ptr const &);
    void disconnect_output(graph_node_ptr const &, uint32_t const bus_idx);

    graph_io_ptr const &add_io(std::optional<io_device_ptr> const &);
    void remove_io();
    std::optional<graph_io_ptr> const &io() const;

    start_result_t start_render();
    void stop();
    bool is_running() const;

    static graph_ptr make_shared();

    // for Test
    std::unordered_set<graph_node_ptr> const &nodes() const;
    graph_connection_set const &connections() const;

   private:
    std::weak_ptr<graph> _weak_graph;
    std::optional<chaining::any_observer_ptr> _io_observer = std::nullopt;

    std::unordered_set<graph_node_ptr> _nodes;
    graph_connection_set _connections;

    graph();

    void _prepare(graph_ptr const &);

    bool _node_exists(graph_node_ptr const &node);
    void _attach_node(graph_node_ptr const &node);
    void _detach_node(graph_node_ptr const &node);
    void _detach_node_if_unused(graph_node_ptr const &node);
    bool _setup_rendering();
    void _dispose_rendering();
    void _disconnect_node_with_predicate(std::function<bool(graph_connection const &)> predicate);
    void _setup_node(graph_node_ptr const &node);
    void _teardown_node(graph_node_ptr const &node);
    bool _add_connection_to_nodes(graph_connection_ptr const &connection);
    void _remove_connection_from_nodes(graph_connection_ptr const &connection);
    void _update_node_connections(graph_node_ptr const &node);
    void _update_all_node_connections();
    graph_connection_set _input_connections_for_destination_node(graph_node_ptr const &node);
    graph_connection_set _output_connections_for_source_node(graph_node_ptr const &node);

    std::optional<graph_io_ptr> _io = std::nullopt;
};
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::graph::start_error_t const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::audio::graph::start_error_t const &);