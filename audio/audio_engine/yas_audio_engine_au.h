//
//  yas_audio_au.h
//

#pragma once

#include <chaining/yas_chaining_umbrella.h>
#include <unordered_map>
#include "yas_audio_engine_au_protocol.h"
#include "yas_audio_engine_node_protocol.h"
#include "yas_audio_engine_ptr.h"
#include "yas_audio_unit.h"

namespace yas::audio::engine {
struct au : manageable_au {
    enum class method {
        will_update_connections,
        did_update_connections,
    };

    using chaining_pair_t = std::pair<method, au_ptr>;
    using prepare_unit_f = std::function<void(audio::unit &)>;

    struct args {
        audio::engine::node_args node_args;
        AudioComponentDescription acd;
    };

    virtual ~au();

    void set_prepare_unit_handler(prepare_unit_f);

    audio::unit_ptr unit() const;
    std::unordered_map<AudioUnitScope, std::unordered_map<AudioUnitParameterID, audio::unit::parameter>> const &
    parameters() const;
    std::unordered_map<AudioUnitParameterID, audio::unit::parameter> const &global_parameters() const;
    std::unordered_map<AudioUnitParameterID, audio::unit::parameter> const &input_parameters() const;
    std::unordered_map<AudioUnitParameterID, audio::unit::parameter> const &output_parameters() const;

    uint32_t input_element_count() const;
    uint32_t output_element_count() const;

    void set_global_parameter_value(AudioUnitParameterID const parameter_id, float const value);
    float global_parameter_value(AudioUnitParameterID const parameter_id) const;
    void set_input_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                   AudioUnitElement const element);
    float input_parameter_value(AudioUnitParameterID const parameter_id, AudioUnitElement const element) const;
    void set_output_parameter_value(AudioUnitParameterID const parameter_id, float const value,
                                    AudioUnitElement const element);
    float output_parameter_value(AudioUnitParameterID const parameter_id, AudioUnitElement const element) const;

    [[nodiscard]] chaining::chain_unsync_t<chaining_pair_t> chain() const;
    [[nodiscard]] chaining::chain_relayed_unsync_t<au_ptr, chaining_pair_t> chain(method const) const;

    audio::engine::node_ptr const &node() const;

    manageable_au_ptr manageable();

   private:
    std::weak_ptr<au> _weak_au;
    audio::engine::node_ptr _node;
    AudioComponentDescription _acd;
    std::unordered_map<AudioUnitScope, unit::parameter_map_t> _parameters;
    chaining::notifier_ptr<chaining_pair_t> _notifier = chaining::notifier<chaining_pair_t>::make_shared();
    chaining::any_observer_ptr _reset_observer = nullptr;
    chaining::any_observer_ptr _connections_observer = nullptr;
    prepare_unit_f _prepare_unit_handler;

    struct core;
    std::unique_ptr<core> _core;

    explicit au(node_args &&);

    void _prepare(au_ptr const &, AudioComponentDescription const &acd);

    au(au const &) = delete;
    au(au &&) = delete;
    au &operator=(au const &) = delete;
    au &operator=(au &&) = delete;

    void prepare_unit() override;
    void prepare_parameters() override;
    void reload_unit() override;

    void _update_unit_connections();
    void _will_reset();

   public:
    static au_ptr make_shared(OSType const type, OSType const sub_type);
    static au_ptr make_shared(AudioComponentDescription const &);
    static au_ptr make_shared(au::args &&);
};
}  // namespace yas::audio::engine
