//
//  yas_audio_avf_au.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <audio/yas_audio_format.h>
#include <audio/yas_audio_ptr.h>
#include <chaining/yas_chaining_umbrella.h>

namespace yas::audio {
enum class avf_au_parameter_scope;

struct avf_au {
    enum load_state {
        unload,
        loaded,
        failed,
    };

    struct render_args {
        audio::pcm_buffer *const buffer;
        uint32_t const bus_idx;
        audio::time const &time;
    };

    using input_render_f = std::function<void(render_args)>;

    AudioComponentDescription componentDescription() const;

    void set_input_bus_count(uint32_t const count);  // for mixer
    void set_output_bus_count(uint32_t const count);
    uint32_t input_bus_count() const;
    uint32_t output_bus_count() const;

    void set_input_format(audio::format const &, uint32_t const bus_idx);
    void set_output_format(audio::format const &, uint32_t const bus_idx);
    audio::format input_format(uint32_t const bus_idx) const;
    audio::format output_format(uint32_t const bus_idx) const;

    void initialize();
    void uninitialize();
    bool is_initialized() const;

    void reset();

    std::string component_name() const;
    std::string audio_unit_name() const;
    std::string audio_unit_short_name() const;
    std::string manufacture_name() const;
    uint32_t component_version() const;

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

    std::optional<avf_au_parameter_ptr> parameter(AudioUnitParameterID const, avf_au_parameter_scope const,
                                                  AudioUnitElement element) const;

    load_state state() const;
    [[nodiscard]] observing::canceller_ptr observe_load_state(observing::caller<load_state>::handler_f &&,
                                                              bool const sync = true);

    // render thread
    void render(render_args const &, input_render_f const &);

    static avf_au_ptr make_shared(OSType const type, OSType const sub_type);
    static avf_au_ptr make_shared(AudioComponentDescription const &);

   private:
    class core;
    std::unique_ptr<core> _core;

    std::vector<avf_au_parameter_ptr> _global_parameters;
    std::vector<avf_au_parameter_ptr> _input_parameters;
    std::vector<avf_au_parameter_ptr> _output_parameters;

    observing::value::holder_ptr<load_state> const _load_state =
        observing::value::holder<load_state>::make_shared(load_state::unload);

    avf_au();

    void _prepare(avf_au_ptr const &, AudioComponentDescription const &);
    void _setup();
    void _update_input_parameters();
    void _update_output_parameters();

    void _set_parameter_value(avf_au_parameter_scope const scope, AudioUnitParameterID const parameter_id,
                              float const value, AudioUnitElement const element);
    float _get_parameter_value(avf_au_parameter_scope const scope, AudioUnitParameterID const parameter_id,
                               AudioUnitElement const element) const;
};
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::avf_au::load_state const &);
}
