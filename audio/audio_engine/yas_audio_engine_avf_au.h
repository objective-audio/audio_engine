//
//  yas_audio_engine_avf_au.h
//

#pragma once

#include "yas_audio_engine_node.h"

namespace yas::audio::engine {
struct avf_au final {
    struct args {
        audio::engine::node_args node_args;
        AudioComponentDescription acd;
    };

    enum load_state {
        unload,
        loaded,
        failed,
    };

    enum connection_method {
        will_update,
        did_update,
    };

    virtual ~avf_au();

    load_state state() const;

    void set_input_bus_count(uint32_t const count);  // for mixer
    void set_output_bus_count(uint32_t const count);
    uint32_t input_bus_count() const;
    uint32_t output_bus_count() const;

    void set_global_parameter_value(AudioUnitParameterID const parameter_id, float const value);
    float global_parameter_value(AudioUnitParameterID const parameter_id) const;
    void set_input_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                   AudioUnitElement const element);
    float input_parameter_value(AudioUnitParameterID const parameter_id, AudioUnitElement const element) const;
    void set_output_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                    AudioUnitElement const element);
    float output_parameter_value(AudioUnitParameterID const parameter_id, AudioUnitElement const element) const;

    std::vector<avf_au_parameter_ptr> const &global_parameters() const;
    std::vector<avf_au_parameter_ptr> const &input_parameters() const;
    std::vector<avf_au_parameter_ptr> const &output_parameters() const;

    audio::engine::node_ptr const &node() const;

    chaining::chain_sync_t<load_state> load_state_chain() const;
    chaining::chain_unsync_t<connection_method> connection_chain() const;

    static avf_au_ptr make_shared(OSType const type, OSType const sub_type);
    static avf_au_ptr make_shared(AudioComponentDescription const &);
    static avf_au_ptr make_shared(args &&);

   private:
    std::weak_ptr<avf_au> _weak_au;
    audio::engine::node_ptr _node;
    AudioComponentDescription _acd;

    std::vector<avf_au_parameter_ptr> _global_parameters;
    std::vector<avf_au_parameter_ptr> _input_parameters;
    std::vector<avf_au_parameter_ptr> _output_parameters;

    chaining::value::holder_ptr<load_state> _load_state =
        chaining::value::holder<load_state>::make_shared(load_state::unload);
    chaining::notifier_ptr<connection_method> _connection_notifier =
        chaining::notifier<connection_method>::make_shared();
    chaining::observer_pool _pool;

    class core;
    std::unique_ptr<core> _core;

    explicit avf_au(node_args &&);

    void _prepare(avf_au_ptr const &, AudioComponentDescription const &acd);
    void _setup();
    void _will_reset();
    void _update_unit_connections();

    void _set_parameter_value(AudioUnitScope const scope, AudioUnitParameterID const parameter_id, float const value,
                              AudioUnitElement const element);
    float _get_parameter_value(AudioUnitScope const scope, AudioUnitParameterID const parameter_id,
                               AudioUnitElement const element) const;

    void _initialize_raw_unit();
    void _uninitialize_raw_unit();
};
}  // namespace yas::audio::engine

namespace yas {
std::string to_string(audio::engine::avf_au::load_state const &);
}
