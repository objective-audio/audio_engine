//
//  yas_audio_unit_impl.h
//

#pragma once

namespace yas {
namespace audio {
    struct unit::impl : base::impl, manageable_unit::impl {
       public:
        std::experimental::optional<uint8_t> _graph_key;
        std::experimental::optional<uint16_t> _key;
        bool initialized;

        impl();
        ~impl();

        void create_audio_unit(AudioComponentDescription const &acd);
        void dispose_audio_unit();

        void initialize() override;
        void uninitialize() override;
        bool is_initialized() const;

        void reset();

        AudioComponentDescription const &acd() const;
        std::string const &name() const;

        void attach_render_callback(uint32_t const bus_idx);
        void detach_render_callback(uint32_t const bus_idx);
        void attach_render_notify();
        void detach_render_notify();
        void attach_input_callback();  // for io
        void detach_input_callback();  // for io

        void set_render_callback(render_f &&callback);
        void set_notify_callback(render_f &&callback);
        void set_input_callback(render_f &&callback);  // for io

        void set_input_format(AudioStreamBasicDescription const &asbd, uint32_t const bus_idx);
        void set_output_format(AudioStreamBasicDescription const &asbd, uint32_t const bus_idx);
        AudioStreamBasicDescription input_format(uint32_t const bus_idx) const;
        AudioStreamBasicDescription output_format(uint32_t const bus_idx) const;

        void set_maximum_frames_per_slice(uint32_t const frames);
        uint32_t maximum_frames_per_slice() const;

        void set_parameter_value(AudioUnitParameterValue const value, AudioUnitParameterID const parameter_id,
                                 AudioUnitScope const scope, AudioUnitElement const element);
        AudioUnitParameterValue parameter_value(AudioUnitParameterID const parameter_id, AudioUnitScope const scope,
                                                AudioUnitElement const element);

        void set_element_count(uint32_t const count, AudioUnitScope const scope);  // for mixer
        uint32_t element_count(AudioUnitScope const scope) const;                  // for mixer

        void set_enable_output(const bool enable_output);  // for io
        bool is_enable_output() const;                     // for io
        void set_enable_input(const bool enable_input);    // for io
        bool is_enable_input() const;                      // for io
        bool has_output() const;                           // for io
        bool has_input() const;                            // for io
        bool is_running() const;                           // for io

        void set_channel_map(const channel_map_t &map, AudioUnitScope const scope,
                             AudioUnitElement const element);                                          // for io
        channel_map_t channel_map(AudioUnitScope const scope, AudioUnitElement const element) const;   // for io
        uint32_t channel_map_count(AudioUnitScope const scope, AudioUnitElement const element) const;  // for io

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)
        void set_current_device(AudioDeviceID const device);  // for io
        AudioDeviceID current_device() const;                 // for io
#endif

        void start();  // for io
        void stop();   // for io

        unit::render_f render_callback() const;  // atomic
        unit::render_f notify_callback() const;  // atomic
        unit::render_f input_callback() const;   // atomic

        void set_audio_unit_instance(AudioUnit const);  // atomic
        AudioUnit audio_unit_instance() const;          // atomic

        void callback_render(render_parameters &render_parameters);           // render thread
        au_result_t audio_unit_render(render_parameters &render_parameters);  // render thread

        template <typename T>
        void set_property_data(std::vector<T> const &data, AudioUnitPropertyID const property_id,
                               AudioUnitScope const scope, AudioUnitElement const element);
        template <typename T>
        std::vector<T> property_data(AudioUnitPropertyID const property_id, AudioUnitScope const scope,
                                     AudioUnitElement const element) const;

        void set_graph_key(std::experimental::optional<uint8_t> const &key) override;
        std::experimental::optional<uint8_t> const &graph_key() const override;
        void set_key(std::experimental::optional<uint16_t> const &) override;
        std::experimental::optional<uint16_t> const &key() const override;

       private:
        class core;
        std::unique_ptr<core> _core;
    };
}
}

#include "yas_audio_unit_impl_private.h"
