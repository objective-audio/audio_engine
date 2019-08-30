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
struct manager : std::enable_shared_from_this<manager> {
    class impl;

   public:
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

    engine::connection &connect(engine::node &source_node, engine::node &destination_node, audio::format const &format);
    engine::connection &connect(engine::node &source_node, engine::node &destination_node,
                                uint32_t const source_bus_idx, uint32_t const destination_bus_idx,
                                audio::format const &format);

    void disconnect(engine::connection &);
    void disconnect(engine::node &);
    void disconnect_input(engine::node const &);
    void disconnect_input(engine::node const &, uint32_t const bus_idx);
    void disconnect_output(engine::node const &);
    void disconnect_output(engine::node const &, uint32_t const bus_idx);

    add_result_t add_offline_output();
    remove_result_t remove_offline_output();
    offline_output_ptr const &offline_output() const;

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    add_result_t add_device_io();
    remove_result_t remove_device_io();
    device_io_ptr const &device_io() const;
#endif

    start_result_t start_render();
    start_result_t start_offline_render(offline_render_f, offline_completion_f);
    void stop();

    [[nodiscard]] chaining::chain_unsync_t<chaining_pair_t> chain() const;
    [[nodiscard]] chaining::chain_relayed_unsync_t<manager_ptr, chaining_pair_t> chain(method const) const;

    // for Test
    std::unordered_set<node_ptr> const &nodes() const;
    engine::connection_set const &connections() const;
    chaining::notifier_ptr<chaining_pair_t> &notifier();

   private:
    std::unique_ptr<impl> _impl;
    chaining::notifier_ptr<chaining_pair_t> _notifier = chaining::notifier<chaining_pair_t>::make_shared();

    audio::graph_ptr _graph = nullptr;
    std::unordered_set<node_ptr> _nodes;
    engine::connection_set _connections;
    offline_output_ptr _offline_output = nullptr;

    manager();

    void prepare();

    bool _node_exists(engine::node &node);
    void _attach_node(engine::node &node);
    void _detach_node(engine::node &node);
    void _detach_node_if_unused(engine::node &node);
    bool _prepare_graph();
    void _disconnect_node_with_predicate(std::function<bool(connection const &)> predicate);
    void _add_node_to_graph(engine::node &node);
    void _remove_node_from_graph(engine::node &node);
    bool _add_connection(engine::connection &connection);
    void _remove_connection_from_nodes(engine::connection const &connection);
    void _update_node_connections(engine::node &node);
    void _update_all_node_connections();
    engine::connection_set _input_connections_for_destination_node(engine::node_ptr const &node);
    engine::connection_set _output_connections_for_source_node(engine::node_ptr const &node);
    void _reload_graph();
    void _post_configuration_change();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    device_io_ptr _device_io = nullptr;
    chaining::any_observer_ptr _device_system_observer = nullptr;

    void _set_device_io(device_io_ptr const &node);
#endif

   public:
    static manager_ptr make_shared();
};
}  // namespace yas::audio::engine

namespace yas {
std::string to_string(audio::engine::manager::method const &);
std::string to_string(audio::engine::manager::start_error_t const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::audio::engine::manager::method const &);
std::ostream &operator<<(std::ostream &, yas::audio::engine::manager::start_error_t const &);
