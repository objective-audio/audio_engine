//
//  yas_audio_unit.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include "yas_audio_types.h"
#include "yas_audio_unit_parameter.h"
#include "yas_exception.h"
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
    class audio_unit;
    using audio_unit_ptr = std::shared_ptr<audio_unit>;
    using channel_map = std::vector<uint32_t>;
    using channel_map_uptr = std::unique_ptr<channel_map>;

    class audio_unit
    {
       public:
        using render_function = std::function<void(render_parameters &)>;

        static const OSType sub_type_default_io();

        static audio_unit_ptr create(const AudioComponentDescription &acd);
        static audio_unit_ptr create(const OSType &type, const OSType &subType);

        ~audio_unit();

        const std::string &name();
        OSType type() const;
        OSType sub_type() const;
        bool is_output_unit() const;
        AudioUnit audio_unit_instance() const;

        void attach_render_callback(const UInt32 &bus);
        void detach_render_callback(const UInt32 &bus);
        void attach_render_notify();
        void detach_render_notify();
        void attach_input_callback();  // for io
        void detach_input_callback();  // for io

        void set_render_callback(const render_function &callback);
        void set_notify_callback(const render_function &callback);
        void set_input_callback(const render_function &callback);  // for io

        template <typename T>
        void set_property_data(const std::unique_ptr<std::vector<T>> &data, const AudioUnitPropertyID property_id,
                               const AudioUnitScope scope, const AudioUnitElement element);
        template <typename T>
        std::unique_ptr<std::vector<T>> property_data(const AudioUnitPropertyID property_id, const AudioUnitScope scope,
                                                      const AudioUnitElement element) const;

        void set_input_format(const AudioStreamBasicDescription &asbd, const UInt32 bus);
        void set_output_format(const AudioStreamBasicDescription &asbd, const UInt32 bus);
        AudioStreamBasicDescription input_format(const UInt32 bus) const;
        AudioStreamBasicDescription output_format(const UInt32 bus) const;
        void set_maximum_frames_per_slice(const UInt32 frames);
        UInt32 maximum_frames_per_slice() const;
        bool is_initialized();

        void set_parameter_value(const AudioUnitParameterValue value, const AudioUnitParameterID parameter_id,
                                 const AudioUnitScope scope, const AudioUnitElement element);
        AudioUnitParameterValue parameter_value(const AudioUnitParameterID parameter_id, const AudioUnitScope scope,
                                                const AudioUnitElement element);

        audio_unit_parameter_map create_parameters(const AudioUnitScope scope);
        audio_unit_parameter create_parameter(const AudioUnitParameterID &parameter_id, const AudioUnitScope scope);

        void set_element_count(const UInt32 &count, const AudioUnitScope &scope);  // for mixer
        UInt32 element_count(const AudioUnitScope &scope) const;                   // for mixer

        void set_enable_output(const bool enable_output);                            // for io
        bool is_enable_output() const;                                               // for io
        void set_enable_input(const bool enable_input);                              // for io
        bool is_enable_input() const;                                                // for io
        bool has_output() const;                                                     // for io
        bool has_input() const;                                                      // for io
        bool is_running() const;                                                     // for io
        void set_channel_map(const channel_map_uptr &, const AudioUnitScope scope);  // for io
        channel_map_uptr channel_map(const AudioUnitScope scope);                    // for io
        uint32_t channel_map_count(const AudioUnitScope scope);                      // for io
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        void set_current_device(const AudioDeviceID &device);  // for io
        const AudioDeviceID current_device() const;            // for io
#endif

        void start();  // for io
        void stop();   // for io
        void reset();

        // render thread

        void callback_render(render_parameters &render_parameters);
        void audio_unit_render(render_parameters &render_parameters);

       private:
        class impl;
        std::unique_ptr<impl> _impl;

        explicit audio_unit(const AudioComponentDescription &acd);
        audio_unit(const OSType &type, const OSType &subType);

        audio_unit(const audio_unit &) = delete;
        audio_unit(const audio_unit &&) = delete;
        audio_unit &operator=(const audio_unit &) = delete;
        audio_unit &operator=(const audio_unit &&) = delete;

        void initialize();
        void uninitialize();
        void set_graph_key(const std::experimental::optional<UInt8> &key);
        const std::experimental::optional<UInt8> &graph_key() const;
        void set_key(const std::experimental::optional<UInt16> &key);
        const std::experimental::optional<UInt16> &key() const;

        friend class audio_graph;
    };
}

#include "yas_audio_unit_private.h"
