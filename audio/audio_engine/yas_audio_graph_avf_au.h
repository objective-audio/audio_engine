//
//  yas_audio_graph_avf_au.h
//

#pragma once

#include <audio/yas_audio_avf_au.h>
#include <audio/yas_audio_graph_node.h>

namespace yas::audio {
struct graph_avf_au final {
    struct args {
        audio::graph_node_args node_args;
        AudioComponentDescription acd;
    };

    using load_state = audio::avf_au::load_state;

    enum connection_method {
        will_update,
        did_update,
    };

    virtual ~graph_avf_au();

    [[nodiscard]] load_state state() const;

    [[nodiscard]] audio::avf_au_ptr const &raw_au() const;

    [[nodiscard]] audio::graph_node_ptr const &node() const;

    [[nodiscard]] chaining::chain_sync_t<load_state> load_state_chain() const;
    [[nodiscard]] chaining::chain_unsync_t<connection_method> connection_chain() const;

    static graph_avf_au_ptr make_shared(OSType const type, OSType const sub_type);
    static graph_avf_au_ptr make_shared(AudioComponentDescription const &);
    static graph_avf_au_ptr make_shared(args &&);

   private:
    audio::graph_node_ptr _node;

    audio::avf_au_ptr const _raw_au;

    std::vector<avf_au_parameter_ptr> _global_parameters;
    std::vector<avf_au_parameter_ptr> _input_parameters;
    std::vector<avf_au_parameter_ptr> _output_parameters;

    chaining::notifier_ptr<connection_method> _connection_notifier =
        chaining::notifier<connection_method>::make_shared();

    explicit graph_avf_au(graph_node_args &&, AudioComponentDescription const &);

    void _will_reset();
    void _update_unit_connections();

    void _initialize_raw_au();
    void _uninitialize_raw_au();
};
}  // namespace yas::audio
