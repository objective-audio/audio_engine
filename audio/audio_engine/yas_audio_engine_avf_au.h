//
//  yas_audio_engine_avf_au.h
//

#pragma once

#include "yas_audio_avf_au.h"
#include "yas_audio_engine_node.h"

namespace yas::audio::engine {
struct avf_au final {
    struct args {
        audio::engine::node_args node_args;
        AudioComponentDescription acd;
    };

    using load_state = audio::avf_au::load_state;

    enum connection_method {
        will_update,
        did_update,
    };

    virtual ~avf_au();

    load_state state() const;

    audio::avf_au_ptr const &raw_au() const;

    audio::engine::node_ptr const &node() const;

    chaining::chain_sync_t<load_state> load_state_chain() const;
    chaining::chain_unsync_t<connection_method> connection_chain() const;

    static avf_au_ptr make_shared(OSType const type, OSType const sub_type);
    static avf_au_ptr make_shared(AudioComponentDescription const &);
    static avf_au_ptr make_shared(args &&);

   private:
    std::weak_ptr<avf_au> _weak_au;
    audio::engine::node_ptr _node;

    audio::avf_au_ptr const _raw_au;

    std::vector<avf_au_parameter_ptr> _global_parameters;
    std::vector<avf_au_parameter_ptr> _input_parameters;
    std::vector<avf_au_parameter_ptr> _output_parameters;

    chaining::value::holder_ptr<load_state> _load_state =
        chaining::value::holder<load_state>::make_shared(load_state::unload);
    chaining::notifier_ptr<connection_method> _connection_notifier =
        chaining::notifier<connection_method>::make_shared();
    chaining::observer_pool _pool;

    explicit avf_au(node_args &&, AudioComponentDescription const &);

    void _prepare(avf_au_ptr const &, AudioComponentDescription const &acd);
    void _will_reset();
    void _update_unit_connections();

    void _initialize_raw_au();
    void _uninitialize_raw_au();
};
}  // namespace yas::audio::engine

namespace yas {
std::string to_string(audio::engine::avf_au::load_state const &);
}
