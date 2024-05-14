//
//  graph_avf_au.h
//

#pragma once

#include <audio-engine/avf_au/avf_au.h>
#include <audio-engine/graph/graph_node.h>

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

    audio::graph_node_ptr const node;
    audio::avf_au_ptr const raw_au;

    [[nodiscard]] observing::syncable observe_load_state(observing::caller<load_state>::handler_f &&);
    [[nodiscard]] observing::endable observe_connection(observing::caller<connection_method>::handler_f &&);

    static graph_avf_au_ptr make_shared(OSType const type, OSType const sub_type);
    static graph_avf_au_ptr make_shared(AudioComponentDescription const &);
    static graph_avf_au_ptr make_shared(args &&);

   private:
    std::vector<avf_au_parameter_ptr> _global_parameters;
    std::vector<avf_au_parameter_ptr> _input_parameters;
    std::vector<avf_au_parameter_ptr> _output_parameters;

    observing::notifier_ptr<connection_method> const _connection_notifier =
        observing::notifier<connection_method>::make_shared();

    explicit graph_avf_au(graph_node_args &&, AudioComponentDescription const &);

    void _will_reset();
    void _update_unit_connections();

    void _initialize_raw_au();
    void _uninitialize_raw_au();
};
}  // namespace yas::audio
