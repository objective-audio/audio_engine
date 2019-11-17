//
//  yas_audio_engine_avf_au.h
//

#pragma once

#include "yas_audio_engine_avf_au_protocol.h"
#include "yas_audio_engine_node.h"

namespace yas::audio::engine {
struct avf_au final : manageable_avf_au {
    struct args {
        audio::engine::node_args node_args;
        AudioComponentDescription acd;
    };

    enum load_state {
        unload,
        loaded,
        failed,
    };

    virtual ~avf_au();

    load_state state() const;

    void set_input_bus_count(uint32_t const count);  // for mixer
    void set_output_bus_count(uint32_t const count);
    uint32_t input_bus_count() const;
    uint32_t output_bus_count() const;

    audio::engine::node_ptr const &node() const;

    chaining::chain_sync_t<load_state> chain() const;

    static avf_au_ptr make_shared(OSType const type, OSType const sub_type);
    static avf_au_ptr make_shared(AudioComponentDescription const &);
    static avf_au_ptr make_shared(args &&);

   private:
    std::weak_ptr<avf_au> _weak_au;
    audio::engine::node_ptr _node;
    AudioComponentDescription _acd;
    chaining::value::holder_ptr<load_state> _load_state =
        chaining::value::holder<load_state>::make_shared(load_state::unload);
    chaining::observer_pool _pool;

    class core;
    std::unique_ptr<core> _core;

    explicit avf_au(node_args &&);

    void _prepare(avf_au_ptr const &, AudioComponentDescription const &acd);
    void _setup();
    void _will_reset();
    void _update_unit_connections();

    void initialize_raw_unit() override;
    void uninitialize_raw_unit() override;
};
}  // namespace yas::audio::engine

namespace yas {
std::string to_string(audio::engine::avf_au::load_state const &);
}
