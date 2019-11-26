//
//  yas_audio_engine_avf_au_parameter.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <chaining/yas_chaining_umbrella.h>
#include <optional>
#include "yas_audio_ptr.h"

namespace yas::audio {
enum avf_au_parameter_scope {
    global,
    input,
    output,
};

struct avf_au_parameter {
    avf_au_parameter_scope scope() const;

    AudioUnitParameterUnit unit() const;

    AUValue min_value() const;
    AUValue max_value() const;

    std::optional<std::string> unit_name() const;

    AUValue value() const;
    void set_value(AUValue const);

    chaining::chain_sync_t<AUValue> chain() const;

    static avf_au_parameter_ptr make_shared(avf_au_parameter_core_ptr const &);

   private:
    avf_au_parameter_core_ptr _core;

    chaining::value::holder_ptr<AUValue> _value;
    chaining::observer_pool _pool;

    avf_au_parameter(avf_au_parameter_core_ptr const &);

    void _prepare(avf_au_parameter_ptr const &);
};
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::avf_au_parameter_scope const &);
}
