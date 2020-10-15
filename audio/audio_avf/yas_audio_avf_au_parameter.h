//
//  yas_audio_graph_avf_au_parameter.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <audio/yas_audio_ptr.h>
#include <chaining/yas_chaining_umbrella.h>

#include <functional>
#include <optional>

namespace yas::audio {
enum class avf_au_parameter_scope {
    global,
    input,
    output,
};

struct avf_au_parameter {
    std::string const key_path;
    std::string const identifier;
    AudioUnitParameterUnit const unit;
    std::optional<std::string> const unit_name;
    std::string const display_name;

    avf_au_parameter_scope scope() const;
    float min_value() const;
    float max_value() const;
    float const &default_value() const;
    std::vector<std::string> const &value_strings() const;

    float value() const;
    void set_value(float const);
    void set_value_at(std::size_t const);
    void reset_value();

    void set_value_changed_handler(std::function<void(float const)> &&);

    static avf_au_parameter_ptr make_shared(std::string &&key_path, std::string &&identifier,
                                            AudioUnitParameterUnit const unit, std::optional<std::string> &&unit_name,
                                            float const default_value, std::string &&display_name,
                                            float const min_value, float const max_value,
                                            std::vector<std::string> &&value_strings, std::vector<float> &&values);

    static avf_au_parameter_scope scope_from_key_path(std::string const &keypath);

   private:
    float const _default_value;
    float const _min_value;
    float const _max_value;
    std::vector<std::string> const _value_strings;
    std::vector<float> const _values;
    float _value;

    std::function<void(float const)> _value_changed_handler;

    avf_au_parameter(std::string &&key_path, std::string &&identifier, AudioUnitParameterUnit const unit,
                     std::optional<std::string> &&unit_name, float const default_value, std::string &&display_name,
                     float const min_value, float const max_value, std::vector<std::string> &&value_strings,
                     std::vector<float> &&values);
};

AudioUnitScope to_raw_scope(avf_au_parameter_scope const);
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::avf_au_parameter_scope const &);
}
