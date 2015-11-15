//
//  yas_audio_unit.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_unit_protocol.h"
#include "yas_audio_unit_parameter.h"
#include "yas_exception.h"
#include "yas_base.h"
#include "yas_result.h"
#include <AudioToolbox/AudioToolbox.h>
#include <vector>
#include <memory>
#include <functional>
#include <exception>
#include <string>
#include <map>
#include <mutex>
#include <experimental/optional>

namespace yas
{
    class audio_unit : public base, public audio_unit_from_graph
    {
        using super_class = base;
        class impl;

       public:
        using render_f = std::function<void(render_parameters &)>;
        using au_result_t = yas::result<std::nullptr_t, OSStatus>;

        static const OSType sub_type_default_io();

        audio_unit(std::nullptr_t);
        explicit audio_unit(const AudioComponentDescription &acd);
        audio_unit(const OSType &type, const OSType &subType);

        ~audio_unit() = default;

        audio_unit(const audio_unit &) = default;
        audio_unit(audio_unit &&) = default;
        audio_unit &operator=(const audio_unit &) = default;
        audio_unit &operator=(audio_unit &&) = default;

        CFStringRef name() const;
        OSType type() const;
        OSType sub_type() const;
        bool is_output_unit() const;
        AudioUnit audio_unit_instance() const;

        void attach_render_callback(const UInt32 &bus_idx) const;
        void detach_render_callback(const UInt32 &bus_idx) const;
        void attach_render_notify() const;
        void detach_render_notify() const;
        void attach_input_callback() const;  // for io
        void detach_input_callback() const;  // for io

        void set_render_callback(const render_f &callback) const;
        void set_notify_callback(const render_f &callback) const;
        void set_input_callback(const render_f &callback) const;  // for io

        void set_input_format(const AudioStreamBasicDescription &asbd, const UInt32 bus_idx) const;
        void set_output_format(const AudioStreamBasicDescription &asbd, const UInt32 bus_idx) const;
        AudioStreamBasicDescription input_format(const UInt32 bus_idx) const;
        AudioStreamBasicDescription output_format(const UInt32 bus_idx) const;
        void set_maximum_frames_per_slice(const UInt32 frames) const;
        UInt32 maximum_frames_per_slice() const;
        bool is_initialized() const;

        void set_parameter_value(const AudioUnitParameterValue value, const AudioUnitParameterID parameter_id,
                                 const AudioUnitScope scope, const AudioUnitElement element) const;
        AudioUnitParameterValue parameter_value(const AudioUnitParameterID parameter_id, const AudioUnitScope scope,
                                                const AudioUnitElement element) const;

        audio_unit_parameter_map_t create_parameters(const AudioUnitScope scope) const;
        audio_unit_parameter create_parameter(const AudioUnitParameterID &parameter_id,
                                              const AudioUnitScope scope) const;

        void set_element_count(const UInt32 &count, const AudioUnitScope &scope) const;  // for mixer
        UInt32 element_count(const AudioUnitScope &scope) const;                         // for mixer

        void set_enable_output(const bool enable_output) const;  // for io
        bool is_enable_output() const;                           // for io
        void set_enable_input(const bool enable_input) const;    // for io
        bool is_enable_input() const;                            // for io
        bool has_output() const;                                 // for io
        bool has_input() const;                                  // for io
        bool is_running() const;                                 // for io
        void set_channel_map(const channel_map_t &map, const AudioUnitScope scope,
                             const AudioUnitElement element) const;                                   // for io
        channel_map_t channel_map(const AudioUnitScope scope, const AudioUnitElement element) const;  // for io
        UInt32 channel_map_count(const AudioUnitScope scope, const AudioUnitElement element) const;   // for io
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        void set_current_device(const AudioDeviceID &device) const;  // for io
        const AudioDeviceID current_device() const;                  // for io
#endif

        void start() const;  // for io
        void stop() const;   // for io
        void reset() const;

        // render thread

        void callback_render(render_parameters &render_parameters);
        au_result_t audio_unit_render(render_parameters &render_parameters);

       private:
        // from graph

        void _initialize() const override;
        void _uninitialize() const override;
        void _set_graph_key(const std::experimental::optional<UInt8> &key) const override;
        const std::experimental::optional<UInt8> &_graph_key() const override;
        void _set_key(const std::experimental::optional<UInt16> &key) const override;
        const std::experimental::optional<UInt16> &_key() const override;

#if YAS_TEST
       public:
        class private_access;
        friend private_access;
#endif
    };

    audio_unit::au_result_t to_result(const OSStatus err);
}

#include "yas_audio_unit_impl.h"

#if YAS_TEST
#include "yas_audio_unit_private_access.h"
#endif
