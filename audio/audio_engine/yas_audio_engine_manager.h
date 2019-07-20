//
//  yas_audio_engine_manager.h
//

#pragma once

#include <chaining/yas_chaining_umbrella.h>
#include <ostream>
#include "yas_audio_engine_connection.h"
#include "yas_audio_engine_offline_output_protocol.h"
#include "yas_audio_graph.h"
#include "yas_audio_types.h"

namespace yas {
template <typename T, typename U>
class result;
}  // namespace yas

namespace yas::audio {
class graph;
}

namespace yas::audio::engine {
class device_io;
class offline_output;

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
    using chaining_pair_t = std::pair<method, std::shared_ptr<manager>>;

    virtual ~manager();

    audio::engine::connection &connect(audio::engine::node &source_node, audio::engine::node &destination_node,
                                       audio::format const &format);
    audio::engine::connection &connect(audio::engine::node &source_node, audio::engine::node &destination_node,
                                       uint32_t const source_bus_idx, uint32_t const destination_bus_idx,
                                       audio::format const &format);

    void disconnect(audio::engine::connection &);
    void disconnect(audio::engine::node &);
    void disconnect_input(audio::engine::node const &);
    void disconnect_input(audio::engine::node const &, uint32_t const bus_idx);
    void disconnect_output(audio::engine::node const &);
    void disconnect_output(audio::engine::node const &, uint32_t const bus_idx);

    add_result_t add_offline_output();
    remove_result_t remove_offline_output();
    std::shared_ptr<audio::engine::offline_output> const &offline_output() const;
    std::shared_ptr<audio::engine::offline_output> &offline_output();

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    add_result_t add_device_io();
    remove_result_t remove_device_io();
    std::shared_ptr<audio::engine::device_io> const &device_io() const;
    std::shared_ptr<audio::engine::device_io> &device_io();
#endif

    start_result_t start_render();
    start_result_t start_offline_render(offline_render_f, offline_completion_f);
    void stop();

    [[nodiscard]] chaining::chain_unsync_t<chaining_pair_t> chain() const;
    [[nodiscard]] chaining::chain_relayed_unsync_t<std::shared_ptr<manager>, chaining_pair_t> chain(method const) const;

    // for Test
    std::unordered_set<std::shared_ptr<node>> const &nodes() const;
    audio::engine::connection_set const &connections() const;
    chaining::notifier<chaining_pair_t> &notifier();

   protected:
    manager();

    void prepare();

   private:
    std::unique_ptr<impl> _impl;
    chaining::notifier<chaining_pair_t> _notifier;
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    std::shared_ptr<audio::engine::device_io> _device_io = nullptr;
    chaining::any_observer_ptr _device_system_observer = nullptr;
#endif

    audio::graph _graph = nullptr;
    std::unordered_set<std::shared_ptr<node>> _nodes;
    audio::engine::connection_set _connections;
    std::shared_ptr<audio::engine::offline_output> _offline_output = nullptr;

    bool _node_exists(audio::engine::node &node);
    void _attach_node(audio::engine::node &node);
    void _detach_node(audio::engine::node &node);
    void _detach_node_if_unused(audio::engine::node &node);
    bool _prepare_graph();
    void _disconnect_node_with_predicate(std::function<bool(connection const &)> predicate);
    void add_node_to_graph(audio::engine::node &node);
    void remove_node_from_graph(audio::engine::node &node);
    bool add_connection(audio::engine::connection &connection);
    void remove_connection_from_nodes(audio::engine::connection const &connection);
    void update_node_connections(audio::engine::node &node);
    void update_all_node_connections();
    audio::engine::connection_set input_connections_for_destination_node(
        std::shared_ptr<audio::engine::node> const &node);
    audio::engine::connection_set output_connections_for_source_node(std::shared_ptr<audio::engine::node> const &node);
    void reload_graph();
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    void set_device_io(std::shared_ptr<audio::engine::device_io> &&node);
#endif
    void post_configuration_change();
};

std::shared_ptr<manager> make_manager();
}  // namespace yas::audio::engine

namespace yas {
std::string to_string(audio::engine::manager::method const &);
std::string to_string(audio::engine::manager::start_error_t const &);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::audio::engine::manager::method const &);
std::ostream &operator<<(std::ostream &, yas::audio::engine::manager::start_error_t const &);
