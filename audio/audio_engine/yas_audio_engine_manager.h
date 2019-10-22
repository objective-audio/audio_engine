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

    enum class add_error_t { already_added };
    enum class remove_error_t { already_removed };

    using start_result_t = result<std::nullptr_t, start_error_t>;
    using add_result_t = result<std::nullptr_t, add_error_t>;
    using remove_result_t = result<std::nullptr_t, remove_error_t>;
    using chaining_pair_t = std::pair<method, manager_ptr>;

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

    add_result_t add_offline_output();
    remove_result_t remove_offline_output();
    offline_output_ptr const &offline_output() const;

    add_result_t add_io();
    remove_result_t remove_io();
    io_ptr const &io() const;

    start_result_t start_render();
    start_result_t start_offline_render(offline_render_f, offline_completion_f);
    void stop();

    [[nodiscard]] chaining::chain_unsync_t<chaining_pair_t> chain() const;
    [[nodiscard]] chaining::chain_relayed_unsync_t<manager_ptr, chaining_pair_t> chain(method const) const;

    static manager_ptr make_shared();

    // for Test
    std::unordered_set<node_ptr> const &nodes() const;
    engine::connection_set const &connections() const;
    chaining::notifier_ptr<chaining_pair_t> &notifier();

   private:
    class impl;

    std::unique_ptr<impl> _impl;

    chaining::notifier_ptr<chaining_pair_t> _notifier = chaining::notifier<chaining_pair_t>::make_shared();

    audio::graph_ptr _graph = nullptr;
    std::unordered_set<node_ptr> _nodes;
    engine::connection_set _connections;
    offline_output_ptr _offline_output = nullptr;

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
    void _post_configuration_change();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    io_ptr _io = nullptr;
    chaining::any_observer_ptr _device_system_observer = nullptr;

    void _set_io(io_ptr const &node);
#endif
};
}  // namespace yas::audio::engine

namespace yas {
std::string to_string(audio::engine::manager::method const &);
std::string to_string(audio::engine::manager::start_error_t const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::audio::engine::manager::method const &);
std::ostream &operator<<(std::ostream &, yas::audio::engine::manager::start_error_t const &);
