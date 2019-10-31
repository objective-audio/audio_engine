//
//  yas_audio_engine_manager.h
//

#pragma once

#include <chaining/yas_chaining_umbrella.h>
#include <ostream>
#include "yas_audio_engine_connection.h"
#include "yas_audio_engine_offline_output_protocol.h"
#include "yas_audio_engine_ptr.h"
#include "yas_audio_graph.h"
#include "yas_audio_types.h"

namespace yas {
template <typename T, typename U>
class result;
}  // namespace yas

namespace yas::audio::engine {
struct manager final {
    enum class method { configuration_change };

    enum class start_error_t {
        already_running,
        prepare_failure,
        connection_not_found,
        offline_output_not_found,
        offline_output_starting_failure,
    };

    using start_result_t = result<std::nullptr_t, start_error_t>;

    virtual ~manager();

    engine::connection_ptr connect(engine::node_ptr const &source_node, engine::node_ptr const &destination_node,
                                   audio::format const &format);
    engine::connection_ptr connect(engine::node_ptr const &source_node, engine::node_ptr const &destination_node,
                                   uint32_t const source_bus_idx, uint32_t const destination_bus_idx,
                                   audio::format const &format);

    void disconnect(engine::connection_ptr const &);
    void disconnect(engine::node_ptr const &);
    void disconnect_input(engine::node_ptr const &);
    void disconnect_input(engine::node_ptr const &, uint32_t const bus_idx);
    void disconnect_output(engine::node_ptr const &);
    void disconnect_output(engine::node_ptr const &, uint32_t const bus_idx);

    offline_output_ptr const &add_offline_output();
    void remove_offline_output();
    std::optional<offline_output_ptr> const &offline_output() const;

    io_ptr const &add_io();
    void remove_io();
    std::optional<io_ptr> const &io() const;

    start_result_t start_render();
    start_result_t start_offline_render(offline_render_f, offline_completion_f);
    void stop();

    [[nodiscard]] chaining::chain_unsync_t<method> chain() const;

    static manager_ptr make_shared();

    // for Test
    std::unordered_set<node_ptr> const &nodes() const;
    engine::connection_set const &connections() const;
    chaining::notifier_ptr<method> &notifier();

   private:
    std::weak_ptr<manager> _weak_manager;
    chaining::notifier_ptr<method> _notifier = chaining::notifier<method>::make_shared();
    chaining::any_observer_ptr _io_observer = nullptr;

    std::optional<audio::graph_ptr> _graph = std::nullopt;
    std::unordered_set<node_ptr> _nodes;
    engine::connection_set _connections;
    std::optional<offline_output_ptr> _offline_output = std::nullopt;

    manager();

    void _prepare(manager_ptr const &);

    bool _node_exists(engine::node_ptr const &node);
    void _attach_node(engine::node_ptr const &node);
    void _detach_node(engine::node_ptr const &node);
    void _detach_node_if_unused(engine::node_ptr const &node);
    bool _prepare_graph();
    void _disconnect_node_with_predicate(std::function<bool(connection const &)> predicate);
    void _add_node_to_graph(engine::node_ptr const &node);
    void _remove_node_from_graph(engine::node_ptr const &node);
    bool _add_connection(engine::connection_ptr const &connection);
    void _remove_connection_from_nodes(engine::connection_ptr const &connection);
    void _update_node_connections(engine::node_ptr const &node);
    void _update_all_node_connections();
    engine::connection_set _input_connections_for_destination_node(engine::node_ptr const &node);
    engine::connection_set _output_connections_for_source_node(engine::node_ptr const &node);
    void _reload_graph();

    std::optional<io_ptr> _io = std::nullopt;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    chaining::any_observer_ptr _device_system_observer = nullptr;
#endif

    void _set_io(std::optional<io_ptr> const &node);
};
}  // namespace yas::audio::engine

namespace yas {
std::string to_string(audio::engine::manager::method const &);
std::string to_string(audio::engine::manager::start_error_t const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::audio::engine::manager::method const &);
std::ostream &operator<<(std::ostream &, yas::audio::engine::manager::start_error_t const &);
