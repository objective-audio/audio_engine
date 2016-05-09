//
//  yas_audio_unit.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <exception>
#include <experimental/optional>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>
#include "yas_audio_types.h"
#include "yas_audio_unit_protocol.h"
#include "yas_base.h"
#include "yas_exception.h"
#include "yas_result.h"

namespace yas {
namespace audio {
    class unit : public base {
        class impl;

       public:
        class parameter;
        using parameter_map_t = std::unordered_map<AudioUnitParameterID, parameter>;

        using render_f = std::function<void(render_parameters &)>;
        using au_result_t = result<std::nullptr_t, OSStatus>;

        static OSType sub_type_default_io();

        unit(std::nullptr_t);
        explicit unit(AudioComponentDescription const &acd);
        unit(OSType const type, OSType const subType);

        ~unit() = default;

        unit(unit const &) = default;
        unit(unit &&) = default;
        unit &operator=(unit const &) = default;
        unit &operator=(unit &&) = default;

        CFStringRef name() const;
        OSType type() const;
        OSType sub_type() const;
        bool is_output_unit() const;
        AudioUnit audio_unit_instance() const;

        void attach_render_callback(uint32_t const bus_idx);
        void detach_render_callback(uint32_t const bus_idx);
        void attach_render_notify();
        void detach_render_notify();
        void attach_input_callback();  // for io
        void detach_input_callback();  // for io

        void set_render_callback(render_f callback);
        void set_notify_callback(render_f callback);
        void set_input_callback(render_f callback);  // for io

        void set_input_format(AudioStreamBasicDescription const &asbd, uint32_t const bus_idx);
        void set_output_format(AudioStreamBasicDescription const &asbd, uint32_t const bus_idx);
        AudioStreamBasicDescription input_format(uint32_t const bus_idx) const;
        AudioStreamBasicDescription output_format(uint32_t const bus_idx) const;
        void set_maximum_frames_per_slice(uint32_t const frames);
        uint32_t maximum_frames_per_slice() const;
        bool is_initialized() const;

        void set_parameter_value(AudioUnitParameterValue const value, AudioUnitParameterID const parameter_id,
                                 AudioUnitScope const scope, AudioUnitElement const element);
        AudioUnitParameterValue parameter_value(AudioUnitParameterID const parameter_id, AudioUnitScope const scope,
                                                AudioUnitElement const element) const;

        parameter_map_t create_parameters(AudioUnitScope const scope) const;
        parameter create_parameter(AudioUnitParameterID const parameter_id, AudioUnitScope const scope) const;

        void set_element_count(uint32_t const count, AudioUnitScope const scope);  // for mixer
        uint32_t element_count(AudioUnitScope const scope) const;                  // for mixer

        void set_enable_output(bool const enable_output);  // for io
        bool is_enable_output() const;                     // for io
        void set_enable_input(bool const enable_input);    // for io
        bool is_enable_input() const;                      // for io
        bool has_output() const;                           // for io
        bool has_input() const;                            // for io
        bool is_running() const;                           // for io
        void set_channel_map(channel_map_t const &map, AudioUnitScope const scope,
                             AudioUnitElement const element);                                          // for io
        channel_map_t channel_map(AudioUnitScope const scope, AudioUnitElement const element) const;   // for io
        uint32_t channel_map_count(AudioUnitScope const scope, AudioUnitElement const element) const;  // for io
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        void set_current_device(AudioDeviceID const device);  // for io
        AudioDeviceID const current_device() const;           // for io
#endif

        void start();  // for io
        void stop();   // for io
        void reset();

        manageable_unit manageable();

        // render thread

        void callback_render(render_parameters &render_parameters);
        au_result_t audio_unit_render(render_parameters &render_parameters);

#if YAS_TEST
       public:
        class private_access;
        friend private_access;
#endif
    };
}

audio::unit::au_result_t to_result(OSStatus const err);
}

#include "yas_audio_unit_impl.h"
#include "yas_audio_unit_parameter.h"

#if YAS_TEST
#include "yas_audio_unit_private_access.h"
#endif
