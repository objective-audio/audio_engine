//
//  yas_audio_unit.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <cpp_utils/yas_base.h>
#include <cpp_utils/yas_exception.h>
#include <functional>
#include <string>
#include <unordered_map>
#include "yas_audio_types.h"
#include "yas_audio_unit_protocol.h"

namespace yas {
template <typename T, typename U>
class result;
}

namespace yas::audio {
struct unit final : base, manageable_unit {
    class impl;
    class parameter;
    using parameter_map_t = std::unordered_map<AudioUnitParameterID, parameter>;

    using render_f = std::function<void(render_parameters &)>;
    using raw_unit_result_t = result<std::nullptr_t, OSStatus>;

    static OSType sub_type_default_io();

    unit(std::nullptr_t);
    explicit unit(AudioComponentDescription const &acd);
    unit(OSType const type, OSType const subType);

    virtual ~unit();

    CFStringRef name() const;
    OSType type() const;
    OSType sub_type() const;
    bool is_output_unit() const;
    AudioUnit raw_unit() const;

    void attach_render_callback(uint32_t const bus_idx);
    void detach_render_callback(uint32_t const bus_idx);
    void attach_render_notify();
    void detach_render_notify();
    void attach_input_callback();  // for io
    void detach_input_callback();  // for io

    void set_render_handler(render_f);
    void set_notify_handler(render_f);
    void set_input_handler(render_f);  // for io

    void set_input_format(AudioStreamBasicDescription const &, uint32_t const bus_idx);
    void set_output_format(AudioStreamBasicDescription const &, uint32_t const bus_idx);
    AudioStreamBasicDescription input_format(uint32_t const bus_idx) const;
    AudioStreamBasicDescription output_format(uint32_t const bus_idx) const;
    void set_maximum_frames_per_slice(uint32_t const);
    uint32_t maximum_frames_per_slice() const;
    bool is_initialized() const;

    void set_parameter_value(AudioUnitParameterValue const, AudioUnitParameterID const, AudioUnitScope const,
                             AudioUnitElement const);
    AudioUnitParameterValue parameter_value(AudioUnitParameterID const, AudioUnitScope const,
                                            AudioUnitElement const) const;

    parameter_map_t create_parameters(AudioUnitScope const) const;
    parameter create_parameter(AudioUnitParameterID const, AudioUnitScope const) const;

    void set_element_count(uint32_t const count, AudioUnitScope const);  // for mixer
    uint32_t element_count(AudioUnitScope const) const;                  // for mixer

    void set_enable_output(bool const enable_output);                                           // for io
    bool is_enable_output() const;                                                              // for io
    void set_enable_input(bool const enable_input);                                             // for io
    bool is_enable_input() const;                                                               // for io
    bool has_output() const;                                                                    // for io
    bool has_input() const;                                                                     // for io
    bool is_running() const;                                                                    // for io
    void set_channel_map(channel_map_t const &, AudioUnitScope const, AudioUnitElement const);  // for io
    channel_map_t channel_map(AudioUnitScope const, AudioUnitElement const) const;              // for io
    uint32_t channel_map_count(AudioUnitScope const, AudioUnitElement const) const;             // for io
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
    void set_current_device(AudioDeviceID const device);  // for io
    AudioDeviceID const current_device() const;           // for io
#endif

    void start();  // for io
    void stop();   // for io
    void reset();

    void initialize() override;
    void uninitialize() override;
    void set_graph_key(std::optional<uint8_t> const &) override;
    std::optional<uint8_t> const &graph_key() const override;
    void set_key(std::optional<uint16_t> const &) override;
    std::optional<uint16_t> const &key() const override;

    // render thread

    void callback_render(render_parameters &render_parameters);
    raw_unit_result_t raw_unit_render(render_parameters &render_parameters);
};
}  // namespace yas::audio

namespace yas {
audio::unit::raw_unit_result_t to_result(OSStatus const err);
}

#include "yas_audio_unit_parameter.h"
