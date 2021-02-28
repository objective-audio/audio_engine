//
//  yas_audio_graph_node.h
//

#pragma once

#include <audio/yas_audio_format.h>
#include <audio/yas_audio_graph_connection.h>
#include <audio/yas_audio_graph_node_protocol.h>
#include <audio/yas_audio_pcm_buffer.h>
#include <audio/yas_audio_ptr.h>
#include <audio/yas_audio_types.h>

#include <optional>
#include <ostream>

namespace yas {
template <typename T, typename U>
class result;
}

namespace yas::audio {
struct graph_node : connectable_graph_node, manageable_graph_node, renderable_graph_node {
    virtual ~graph_node();

    void reset();

    [[nodiscard]] graph_connection_ptr input_connection(uint32_t const bus_idx) const override;
    [[nodiscard]] graph_connection_ptr output_connection(uint32_t const bus_idx) const override;
    [[nodiscard]] graph_connection_wmap const &input_connections() const override;
    [[nodiscard]] graph_connection_wmap const &output_connections() const override;

    [[nodiscard]] std::optional<audio::format> input_format(uint32_t const bus_idx) const;
    [[nodiscard]] std::optional<audio::format> output_format(uint32_t const bus_idx) const;
    [[nodiscard]] bus_result_t next_available_input_bus() const;
    [[nodiscard]] bus_result_t next_available_output_bus() const;
    [[nodiscard]] bool is_available_input_bus(uint32_t const bus_idx) const;
    [[nodiscard]] bool is_available_output_bus(uint32_t const bus_idx) const;
    [[nodiscard]] audio::graph_ptr graph() const override;

    [[nodiscard]] uint32_t input_bus_count() const;
    [[nodiscard]] uint32_t output_bus_count() const;
    [[nodiscard]] bool is_input_renderable() const override;

    void set_render_handler(node_render_f);
    [[nodiscard]] node_render_f const render_handler() const override;

    static graph_node_ptr make_shared(graph_node_args);

   private:
    std::weak_ptr<audio::graph> _weak_graph;
    uint32_t _input_bus_count = 0;
    uint32_t _output_bus_count = 0;
    bool _is_input_renderable = false;
    std::optional<uint32_t> _override_output_bus_idx = std::nullopt;
    audio::graph_connection_wmap _input_connections;
    audio::graph_connection_wmap _output_connections;
    graph_node_f _setup_handler;
    graph_node_f _teardown_handler;
    graph_node_f _prepare_rendering_handler;
    graph_node_f _update_rendering_handler;
    graph_node_f _will_reset_handler;
    audio::node_render_f _render_handler;

    explicit graph_node(graph_node_args &&);

    void add_connection(audio::graph_connection_ptr const &) override;
    void remove_input_connection(uint32_t const dst_bus) override;
    void remove_output_connection(uint32_t const src_bus) override;

    void set_graph(audio::graph_wptr const &) override;
    void set_setup_handler(graph_node_f &&) override;
    void set_teardown_handler(graph_node_f &&) override;
    void set_prepare_rendering_handler(graph_node_f &&) override;
    void set_update_rendering_handler(graph_node_f &&) override;
    void set_will_reset_handler(graph_node_f &&) override;
    graph_node_f const &setup_handler() const override;
    graph_node_f const &teardown_handler() const override;
    void prepare_rendering() override;
    void update_rendering() override;

    graph_node(graph_node &&) = delete;
    graph_node &operator=(graph_node &&) = delete;
    graph_node(graph_node const &) = delete;
    graph_node &operator=(graph_node const &) = delete;
};
}  // namespace yas::audio
