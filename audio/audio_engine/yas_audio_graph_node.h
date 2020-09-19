//
//  yas_audio_graph_node.h
//

#pragma once

#include <audio/yas_audio_format.h>
#include <audio/yas_audio_graph_connection.h>
#include <audio/yas_audio_graph_node_protocol.h>
#include <audio/yas_audio_pcm_buffer.h>
#include <audio/yas_audio_ptr.h>
#include <audio/yas_audio_rendering_types.h>
#include <audio/yas_audio_types.h>
#include <chaining/yas_chaining_umbrella.h>

#include <optional>
#include <ostream>

namespace yas {
template <typename T, typename U>
class result;
}

namespace yas::audio {
struct graph_node : connectable_graph_node, manageable_graph_node {
    enum class method {
        will_reset,
        update_connections,
    };

    using chaining_pair_t = std::pair<method, graph_node_ptr>;

    using prepare_kernel_f = std::function<void(graph_kernel &)>;
    using render_f = std::function<void(node_render_args)>;

    virtual ~graph_node();

    void reset();

    graph_connection_ptr input_connection(uint32_t const bus_idx) const override;
    graph_connection_ptr output_connection(uint32_t const bus_idx) const override;
    graph_connection_wmap const &input_connections() const override;
    graph_connection_wmap const &output_connections() const override;

    std::optional<audio::format> input_format(uint32_t const bus_idx) const;
    std::optional<audio::format> output_format(uint32_t const bus_idx) const;
    bus_result_t next_available_input_bus() const;
    bus_result_t next_available_output_bus() const;
    bool is_available_input_bus(uint32_t const bus_idx) const;
    bool is_available_output_bus(uint32_t const bus_idx) const;
    audio::graph_ptr graph() const override;
    std::optional<audio::time> last_render_time() const;

    uint32_t input_bus_count() const;
    uint32_t output_bus_count() const;
    bool is_input_renderable() const;

    void set_prepare_kernel_handler(prepare_kernel_f);
    void set_render_handler(render_f);
    render_f const render_handler() const;

    std::optional<graph_kernel_ptr> kernel() const;

    void render(node_render_args);
    void set_render_time_on_render(audio::time const &time);

    [[nodiscard]] chaining::chain_unsync_t<chaining_pair_t> chain() const;
    [[nodiscard]] chaining::chain_relayed_unsync_t<graph_node_ptr, chaining_pair_t> chain(method const) const;

    static graph_node_ptr make_shared(graph_node_args);

   private:
    std::weak_ptr<graph_node> _weak_node;
    std::weak_ptr<audio::graph> _weak_graph;
    uint32_t _input_bus_count = 0;
    uint32_t _output_bus_count = 0;
    bool _is_input_renderable = false;
    std::optional<uint32_t> _override_output_bus_idx = std::nullopt;
    audio::graph_connection_wmap _input_connections;
    audio::graph_connection_wmap _output_connections;
    graph_node_setup_f _setup_handler;
    graph_node_setup_f _teardown_handler;
    prepare_kernel_f _prepare_kernel_handler;
    audio::graph_node::render_f _render_handler;
    chaining::notifier_ptr<chaining_pair_t> _notifier = chaining::notifier<chaining_pair_t>::make_shared();

    struct core;
    std::unique_ptr<core> _core;

    explicit graph_node(graph_node_args &&);

    void _prepare(graph_node_ptr const &);
    void _prepare_kernel(graph_kernel_ptr const &kernel);

    void add_connection(audio::graph_connection_ptr const &) override;
    void remove_input_connection(uint32_t const dst_bus) override;
    void remove_output_connection(uint32_t const src_bus) override;

    void set_graph(audio::graph_wptr const &) override;
    void update_kernel() override;
    void update_connections() override;
    void set_setup_handler(graph_node_setup_f &&) override;
    void set_teardown_handler(graph_node_setup_f &&) override;
    graph_node_setup_f const &setup_handler() const override;
    graph_node_setup_f const &teardown_handler() const override;

    graph_node(graph_node &&) = delete;
    graph_node &operator=(graph_node &&) = delete;
    graph_node(graph_node const &) = delete;
    graph_node &operator=(graph_node const &) = delete;
};
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::graph_node::method const &);
}

std::ostream &operator<<(std::ostream &, yas::audio::graph_node::method const &);

#include <audio/yas_audio_graph_kernel.h>
