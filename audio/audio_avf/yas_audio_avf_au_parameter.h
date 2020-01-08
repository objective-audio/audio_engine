//
//  yas_audio_graph_avf_au_parameter.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <chaining/yas_chaining_umbrella.h>
#include <optional>
#include "yas_audio_ptr.h"

namespace yas::audio {
enum class avf_au_parameter_scope {
    global,
    input,
    output,
};

struct avf_au_parameter {
    std::string key_path() const;
    avf_au_parameter_scope scope() const;
    std::string identifier() const;
    AudioUnitParameterUnit unit() const;
    std::optional<std::string> unit_name() const;
    std::string display_name() const;

    float min_value() const;
    float max_value() const;
    float const &default_value() const;
    std::vector<std::string> const &value_strings() const;

    float value() const;
    void set_value(float const);
    void set_value_at(std::size_t const);
    void reset_value();

    chaining::chain_sync_t<float> chain() const;

    static avf_au_parameter_ptr make_shared(avf_au_parameter_core_ptr const &);

   private:
    avf_au_parameter_core_ptr _core;

    float const _default_value;
    std::vector<std::string> const _value_strings;
    chaining::value::holder_ptr<float> _value;
    chaining::observer_pool _pool;

    avf_au_parameter(avf_au_parameter_core_ptr const &);

    void _prepare(avf_au_parameter_ptr const &);
};

AudioUnitScope to_raw_scope(avf_au_parameter_scope const);
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::avf_au_parameter_scope const &);
}
