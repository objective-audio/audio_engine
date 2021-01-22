//
//  yas_audio_graph.h
//

#pragma once

#include <audio/yas_audio_graph_connection.h>
#include <audio/yas_audio_graph_node.h>
#include <chaining/yas_chaining_umbrella.h>

#include <ostream>

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
    [[nodiscard]] std::optional<graph_io_ptr> const &io() const;

    start_result_t start_render();
    void stop();
    [[nodiscard]] bool is_running() const;

    [[nodiscard]] static graph_ptr make_shared();

    // for Test
    graph_node_set const &nodes() const;
    graph_connection_set const &connections() const;

   private:
    std::weak_ptr<graph> _weak_graph;
    std::optional<observing::canceller_ptr> _io_observer = std::nullopt;

    graph_node_set _nodes;
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
    graph_connection_set _input_connections_for_destination_node(graph_node_ptr const &node);
    graph_connection_set _output_connections_for_source_node(graph_node_ptr const &node);
    void _update_io_rendering();
    void _clear_io_rendering();

    std::optional<graph_io_ptr> _io = std::nullopt;
};
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::graph::start_error_t const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::audio::graph::start_error_t const &);
